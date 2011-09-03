/*
	File:       BetterAuthorizationSampleLib.c

    Contains:   Implementation of reusable code for privileged helper tools.

    Written by: DTS

    Copyright:  Copyright (c) 2007 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple, Inc.
                ("Apple") in consideration of your agreement to the following terms, and your
                use, installation, modification or redistribution of this Apple software
                constitutes acceptance of these terms.  If you do not agree with these terms,
                please do not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following terms, and subject
                to these terms, Apple grants you a personal, non-exclusive license, under Apple's
                copyrights in this original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or without
                modifications, in source and/or binary forms; provided that if you redistribute
                the Apple Software in its entirety and without modifications, you must retain
                this notice and the following text and disclaimers in all such redistributions of
                the Apple Software.  Neither the name, trademarks, service marks or logos of
                Apple, Inc. may be used to endorse or promote products derived from the
                Apple Software without specific prior written permission from Apple.  Except as
                expressly stated in this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any patent rights that
                may be infringed by your derivative works or by other works in which the Apple
                Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
                WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
                WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
                PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
                CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
                GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
                ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
                (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
                ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

// Define BAS_PRIVATE so that we pick up our private definitions from 
// "BetterAuthorizationSampleLib.h".

#define BAS_PRIVATE 1

#include "BetterAuthorizationSampleLib.h"

#include <launch.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/event.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/socket.h>

// At runtime BAS only requires CoreFoundation.  However, at build time we need 
// CoreServices for the various OSStatus error codes in "MacErrors.h".  Thus, by default, 
// we include CoreServices at build time.  However, you can flip this switch to check 
// that you're not accidentally using any other CoreServices things.

#if 1
    #include <CoreServices/CoreServices.h>
#else
    #warning Do not ship this way!
    #include <CoreFoundation/CoreFoundation.h>
    #include "/System/Library/Frameworks/CoreServices.framework/Frameworks/CarbonCore.framework/Headers/MacErrors.h"
#endif

//////////////////////////////////////////////////////////////////////////////////
#pragma mark ***** Constants

enum {
    kIdleTimeoutInSeconds     = 120,        // if we get no requests in 2 minutes, we quit
    kWatchdogTimeoutInSeconds = 65          // any given request must be completely in 65 seconds
};

// IMPORTANT:
// These values must be greater than 60 seconds.  If a job runs for less than 60 
// seconds, launchd will consider it to have failed.

// kBASMaxNumberOfKBytes has two uses:
//
// 1. When receiving a dictionary, it is used to limit the size of the incoming 
//    data.  This ensures that a non-privileged client can't exhaust the 
//    address space of a privileged helper tool.
//
// 2. Because it's less than 4 GB, this limit ensures that the dictionary size 
//    can be sent as an architecture-neutral uint32_t.

#define kBASMaxNumberOfKBytes			(1024 * 1024)

// A hard-wired file system path for the UNIX domain socket; %s is the placeholder 
// for the bundle ID (in file system representation).

#define kBASSocketPathFormat			"/var/run/%s.socket"

// The key used to get our describe our socket in the launchd property list file.

#define kLaunchDSocketDictKey           "MasterSocket"

/////////////////////////////////////////////////////////////////
#pragma mark ***** Common Code

extern int BASOSStatusToErrno(OSStatus errNum)
    // See comment in header.
{
	int retval;
    
    #define CASE(ident)         \
        case k ## ident ## Err: \
            retval = ident;     \
            break
    switch (errNum) {
		case noErr:
			retval = 0;
			break;
        case kENORSRCErr:
            retval = ESRCH;                 // no ENORSRC on Mac OS X, so use ESRCH
            break;
        case memFullErr:
            retval = ENOMEM;
            break;
        CASE(EDEADLK);
        CASE(EAGAIN);
		case kEOPNOTSUPPErr:
			retval = ENOTSUP;
			break;
        CASE(EPROTO);
        CASE(ETIME);
        CASE(ENOSR);
        CASE(EBADMSG);
        case kECANCELErr:
            retval = ECANCELED;             // note spelling difference
            break;
        CASE(ENOSTR);
        CASE(ENODATA);
        CASE(EINPROGRESS);
        CASE(ESRCH);
        CASE(ENOMSG);
        default:
            if ( (errNum <= kEPERMErr) && (errNum >= kENOMSGErr) ) {
				retval = (-3200 - errNum) + 1;				// OT based error
            } else if ( (errNum >= errSecErrnoBase) && (errNum <= (errSecErrnoBase + ELAST)) ) {
                retval = (int) errNum - errSecErrnoBase;	// POSIX based error
            } else {
				retval = (int) errNum;						// just return the value unmodified
			}
    }
    #undef CASE
    return retval;
}

extern OSStatus BASErrnoToOSStatus(int errNum)
    // See comment in header.
{
	OSStatus retval;
	
	if ( errNum == 0 ) {
		retval = noErr;
	} else if ( (errNum >= EPERM) && (errNum <= ELAST) ) {
		retval = (OSStatus) errNum + errSecErrnoBase;
	} else {
		retval = (int) errNum;      // just return the value unmodified
	}
    
    return retval;
}

static Boolean BASIsBinaryPropertyListData(const void * plistBuffer, size_t plistSize)
	// Make sure that whatever is passed into the buffer that will 
	// eventually become a plist (and then sequentially a dictionary)
	// is NOT in binary format.
{
    static const char kBASBinaryPlistWatermark[6] = "bplist";
    
    assert(plistBuffer != NULL);
	
	return (plistSize >= sizeof(kBASBinaryPlistWatermark)) 
        && (memcmp(plistBuffer, kBASBinaryPlistWatermark, sizeof(kBASBinaryPlistWatermark)) == 0);
}

static void NormaliseOSStatusErrorCode(OSStatus *errPtr)
    // Normalise the cancelled error code to reduce the number of checks that our clients 
    // have to do.  I made this a function in case I ever want to expand this to handle 
    // more than just this one case.
{
    assert(errPtr != NULL);
    
    if ( (*errPtr == errAuthorizationCanceled) || (*errPtr == (errSecErrnoBase + ECANCELED)) ) {
        *errPtr = userCanceledErr;
    }
}

static int BASRead(int fd, void *buf, size_t bufSize, size_t *bytesRead)
	// A wrapper around <x-man-page://2/read> that keeps reading until either 
	// bufSize bytes are read or until EOF is encountered, in which case you get 
    // EPIPE.
	//
	// If bytesRead is not NULL, *bytesRead will be set to the number 
	// of bytes successfully read.  On success, this will always be equal to 
    // bufSize.  On error, it indicates how much was read before the error 
    // occurred (which could be zero).
{
	int 	err;
	char *	cursor;
	size_t	bytesLeft;
	ssize_t bytesThisTime;

    // Pre-conditions

	assert(fd >= 0);
	assert(buf != NULL);
    // bufSize may be 0
	assert(bufSize <= kBASMaxNumberOfKBytes);
    // bytesRead may be NULL
	
	err = 0;
	bytesLeft = bufSize;
	cursor = (char *) buf;
	while ( (err == 0) && (bytesLeft != 0) ) {
		bytesThisTime = read(fd, cursor, bytesLeft);
		if (bytesThisTime > 0) {
			cursor    += bytesThisTime;
			bytesLeft -= bytesThisTime;
		} else if (bytesThisTime == 0) {
			err = EPIPE;
		} else {
			assert(bytesThisTime == -1);
			
			err = errno;
			assert(err != 0);
			if (err == EINTR) {
				err = 0;		// let's loop again
			}
		}
	}
	if (bytesRead != NULL) {
		*bytesRead = bufSize - bytesLeft;
	}
	
	return err;
}

static int BASWrite(int fd, const void *buf, size_t bufSize, size_t *bytesWritten)
	// A wrapper around <x-man-page://2/write> that keeps writing until either 
	// all the data is written or an error occurs, in which case 
	// you get EPIPE.
	//
	// If bytesWritten is not NULL, *bytesWritten will be set to the number 
	// of bytes successfully written.  On success, this will always be equal to 
    // bufSize.  On error, it indicates how much was written before the error 
    // occurred (which could be zero).
{
	int 	err;
	char *	cursor;
	size_t	bytesLeft;
	ssize_t bytesThisTime;
	
    // Pre-conditions

	assert(fd >= 0);
	assert(buf != NULL);
    // bufSize may be 0
	assert(bufSize <= kBASMaxNumberOfKBytes);
	// bytesWritten may be NULL
	
	// SIGPIPE occurs when you write to pipe or socket 
	// whose other end has been closed.  The default action 
	// for SIGPIPE is to terminate the process.  That's 
	// probably not what you wanted.  So, in the debug build, 
	// we check that you've set the signal action to SIG_IGN 
	// (ignore).  Of course, you could be building a program 
	// that needs SIGPIPE to work in some special way, in 
	// which case you should define BAS_WRITE_CHECK_SIGPIPE 
	// to 0 to bypass this check.
	
	#if !defined(BAS_WRITE_CHECK_SIGPIPE)
		#define BAS_WRITE_CHECK_SIGPIPE 1
	#endif
	#if !defined(NDEBUG) && BAS_WRITE_CHECK_SIGPIPE
		{
			int					junk;
			struct stat			sb;
			struct sigaction	currentSignalState;
			int					val;
			socklen_t			valLen;
			
			junk = fstat(fd, &sb);
			assert(junk == 0);
			
			if ( S_ISFIFO(sb.st_mode) || S_ISSOCK(sb.st_mode) ) {
				junk = sigaction(SIGPIPE, NULL, &currentSignalState);
				assert(junk == 0);
				
				valLen = sizeof(val);
				junk = getsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &val, &valLen);
				assert(junk == 0);
				assert(valLen == sizeof(val));

				// If you hit this assertion, you need to either disable SIGPIPE in 
				// your process or on the specific socket you're writing to.  The 
				// standard code for the former is:
				//
				// (void) signal(SIGPIPE, SIG_IGN);
				//
				// You typically add this code to your main function.
				//
				// The standard code for the latter is:
				//
				// static const int kOne = 1;
				// err = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &kOne, sizeof(kOne));
				//
				// You typically do this just after creating the socket.

				assert( (currentSignalState.sa_handler == SIG_IGN) || (val == 1) );
			}
		}
	#endif

	err = 0;
	bytesLeft = bufSize;
	cursor = (char *) buf;
	while ( (err == 0) && (bytesLeft != 0) ) {
		bytesThisTime = write(fd, cursor, bytesLeft);
		if (bytesThisTime > 0) {
			cursor    += bytesThisTime;
			bytesLeft -= bytesThisTime;
		} else if (bytesThisTime == 0) {
			assert(false);
			err = EPIPE;
		} else {
			assert(bytesThisTime == -1);
			
			err = errno;
			assert(err != 0);
			if (err == EINTR) {
				err = 0;		// let's loop again
			}
		}
	}
	if (bytesWritten != NULL) {
		*bytesWritten = bufSize - bytesLeft;
	}
	
	return err;
}

static int BASReadDictionary(int fdIn, CFDictionaryRef *dictPtr)
	// Create a CFDictionary by reading the XML data from fdIn. 
	// It first reads the size of the XML data, then allocates a 
	// buffer for that data, then reads the data in, and finally 
	// unflattens the data into a CFDictionary.
    //
    // On success, the caller is responsible for releasing *dictPtr.
	//
	// See also the companion routine, BASWriteDictionary, below.
{
	int                 err = 0;
	uint32_t			dictSize;
	void *				dictBuffer;
	CFDataRef			dictData;
	CFPropertyListRef 	dict;

    // Pre-conditions

	assert(fdIn >= 0);
	assert( dictPtr != NULL);
	assert(*dictPtr == NULL);
	
	dictBuffer = NULL;
	dictData   = NULL;
	dict       = NULL;

	// Read the data size and allocate a buffer.  Always read the length as a big-endian 
    // uint32_t, so that the app and the helper tool can be different architectures.
	
	err = BASRead(fdIn, &dictSize, sizeof(dictSize), NULL);
	if (err == 0) {
        dictSize = OSSwapBigToHostInt32(dictSize);
		if (dictSize == 0) {
			// According to the C language spec malloc(0) may return NULL (although the Mac OS X 
            // malloc doesn't ever do this), so we specifically check for and error out in 
			// that case.
			err = EINVAL;
		} else if (dictSize > kBASMaxNumberOfKBytes) {
			// Abitrary limit to prevent potentially hostile client overwhelming us with data.
			err = EINVAL;
		}
	}
	if (err == 0) {
		dictBuffer = malloc( (size_t) dictSize);
		if (dictBuffer == NULL) {
			err = ENOMEM;
		}
	}
	
	// Read the data and unflatten.
	
	if (err == 0) {
		err = BASRead(fdIn, dictBuffer, dictSize, NULL);
	}
	if ( (err == 0) && BASIsBinaryPropertyListData(dictBuffer, dictSize) ) {
        err = BASOSStatusToErrno( coreFoundationUnknownErr );
	}
	if (err == 0) {
		dictData = CFDataCreateWithBytesNoCopy(NULL, dictBuffer, dictSize, kCFAllocatorNull);
		if (dictData == NULL) {
			err = BASOSStatusToErrno( coreFoundationUnknownErr );
		}
	}
	if (err == 0) {
		dict = CFPropertyListCreateFromXMLData(NULL, dictData, kCFPropertyListImmutable, NULL);
		if (dict == NULL) {
			err = BASOSStatusToErrno( coreFoundationUnknownErr );
		}
	}
	if ( (err == 0) && (CFGetTypeID(dict) != CFDictionaryGetTypeID()) ) {
		err = EINVAL;		// only CFDictionaries need apply
	}
	// CFShow(dict);
	
	// Clean up.
	
	if (err != 0) {
		if (dict != NULL) {
			CFRelease(dict);
		}
		dict = NULL;
	}
	*dictPtr = (CFDictionaryRef) dict;
	free(dictBuffer);
	if (dictData != NULL) {
		CFRelease(dictData);
	}
	
	assert( (err == 0) == (*dictPtr != NULL) );
	
	return err;
}

static int BASWriteDictionary(CFDictionaryRef dict, int fdOut)
	// Write a dictionary to a file descriptor by flattening 
	// it into XML.  Send the size of the XML before sending 
	// the data so that BASReadDictionary knows how much to 
	// read.
	//
	// See also the companion routine, BASReadDictionary, above.
{
	int                 err = 0;
	CFDataRef			dictData;
	uint32_t			dictSize;

    // Pre-conditions

	assert(dict != NULL);
	assert(fdOut >= 0);
	
	dictData   = NULL;
	
    // Get the dictionary as XML data.
    
	dictData = CFPropertyListCreateXMLData(NULL, dict);
	if (dictData == NULL) {
		err = BASOSStatusToErrno( coreFoundationUnknownErr );
	}
    
    // Send the length, then send the data.  Always send the length as a big-endian 
    // uint32_t, so that the app and the helper tool can be different architectures.
    //
    // The MoreAuthSample version of this code erroneously assumed that CFDataGetBytePtr 
    // can fail and thus allocated an extra buffer to copy the data into.  In reality, 
    // CFDataGetBytePtr can't fail, so this version of the code doesn't do the unnecessary 
    // allocation.
    
    if ( (err == 0) && (CFDataGetLength(dictData) > kBASMaxNumberOfKBytes) ) {
        err = EINVAL;
    }
    if (err == 0) {
		dictSize = OSSwapHostToBigInt32( CFDataGetLength(dictData) );
        err = BASWrite(fdOut, &dictSize, sizeof(dictSize), NULL);
    }
	if (err == 0) {
		err = BASWrite(fdOut, CFDataGetBytePtr(dictData), CFDataGetLength(dictData), NULL);
	}

	if (dictData != NULL) {
		CFRelease(dictData);
	}
		
	return err;
}

// When we pass a descriptor, we have to pass at least one byte 
// of data along with it, otherwise the recvmsg call will not 
// block if the descriptor hasn't been written to the other end 
// of the socket yet.

static const char kDummyData = 'D';

// Due to a kernel bug in Mac OS X 10.4.x and earlier <rdar://problem/4650646>, 
// you will run into problems if you write data to a socket while a process is 
// trying to receive a descriptor from that socket.  A common symptom of this 
// problem is that, if you write two descriptors back-to-back, the second one 
// just disappears.
//
// To avoid this problem, we explicitly ACK all descriptor transfers.  
// After writing a descriptor, the sender reads an ACK byte from the socket.  
// After reading a descriptor, the receiver sends an ACK byte (kACKData) 
// to unblock the sender.

static const char kACKData   = 'A';

static int BASReadDescriptor(int fd, int *fdRead)
    // Read a descriptor from fd and place it in *fdRead.
    //
    // On success, the caller is responsible for closing *fdRead.
    //
    // See the associated BASWriteDescriptor, below.
{
	int 				err;
	int 				junk;
	struct msghdr 		msg;
	struct iovec		iov;
	struct {
		struct cmsghdr 	hdr;
		int            	fd;
	} 					control;
	char				dummyData;
	ssize_t				bytesReceived;

    // Pre-conditions

	assert(fd >= 0);
	assert( fdRead != NULL);
	assert(*fdRead == -1);

	iov.iov_base = (char *) &dummyData;
	iov.iov_len  = sizeof(dummyData);
	
    msg.msg_name       = NULL;
    msg.msg_namelen    = 0;
    msg.msg_iov        = &iov;
    msg.msg_iovlen     = 1;
    msg.msg_control    = (caddr_t) &control;
    msg.msg_controllen = sizeof(control);
    msg.msg_flags	   = MSG_WAITALL;
    
    do {
	    bytesReceived = recvmsg(fd, &msg, 0);
	    if (bytesReceived == sizeof(dummyData)) {
	    	if (   (dummyData != kDummyData)
	    		|| (msg.msg_flags != 0) 
	    		|| (msg.msg_control == NULL) 
	    		|| (msg.msg_controllen != sizeof(control)) 
	    		|| (control.hdr.cmsg_len != sizeof(control)) 
	    		|| (control.hdr.cmsg_level != SOL_SOCKET)
				|| (control.hdr.cmsg_type  != SCM_RIGHTS) 
				|| (control.fd < 0) ) {
	    		err = EINVAL;
	    	} else {
	    		*fdRead = control.fd;
		    	err = 0;
	    	}
	    } else if (bytesReceived == 0) {
	    	err = EPIPE;
	    } else {
	    	assert(bytesReceived == -1);

	    	err = errno;
	    	assert(err != 0);
	    }
	} while (err == EINTR);
    
    // Send the ACK.  If that fails, we have to act like we never got the 
    // descriptor in our to maintain our post condition.
    
    if (err == 0) {
        err = BASWrite(fd, &kACKData, sizeof(kACKData), NULL);
        if (err != 0) {
            junk = close(*fdRead);
            assert(junk == 0);
            *fdRead = -1;
        }
    }

	assert( (err == 0) == (*fdRead >= 0) );
	
	return err;
}

static int BASWriteDescriptor(int fd, int fdToWrite)
    // Write the descriptor fdToWrite to fd.
    //
    // See the associated BASReadDescriptor, above.
{
	int 				err;
	struct msghdr 		msg;
	struct iovec		iov;
	struct {
		struct cmsghdr 	hdr;
		int            	fd;
	} 					control;
	ssize_t 			bytesSent;
    char                ack;

    // Pre-conditions

	assert(fd >= 0);
	assert(fdToWrite >= 0);

    control.hdr.cmsg_len   = sizeof(control);
    control.hdr.cmsg_level = SOL_SOCKET;
    control.hdr.cmsg_type  = SCM_RIGHTS;
    control.fd             = fdToWrite;

	iov.iov_base = (char *) &kDummyData;
	iov.iov_len  = sizeof(kDummyData);
	
    msg.msg_name       = NULL;
    msg.msg_namelen    = 0;
    msg.msg_iov        = &iov;
    msg.msg_iovlen     = 1;
    msg.msg_control    = (caddr_t) &control;
    msg.msg_controllen = control.hdr.cmsg_len;
    msg.msg_flags	   = 0;
    do {
	    bytesSent = sendmsg(fd, &msg, 0);
	    if (bytesSent == sizeof(kDummyData)) {
	    	err = 0;
	    } else {
	    	assert(bytesSent == -1);

	    	err = errno;
	    	assert(err != 0);
	    }
	} while (err == EINTR);

    // After writing the descriptor, try to read an ACK back from the 
    // recipient.  If that fails, or we get the wrong ACK, we've failed.
    
    if (err == 0) {
        err = BASRead(fd, &ack, sizeof(ack), NULL);
        if ( (err == 0) && (ack != kACKData) ) {
            err = EINVAL;
        }
    }

    return err;
}

extern void BASCloseDescriptorArray(
	CFArrayRef					descArray
)
    // See comment in header.
{	
	int							junk;
	CFIndex						descCount;
	CFIndex						descIndex;
	
	// I decided to allow descArray to be NULL because it makes it 
	// easier to call this routine using the code.
	//
	// BASCloseDescriptorArray((CFArrayRef) CFDictionaryGetValue(response, CFSTR(kBASDescriptorArrayKey)));
	
	if (descArray != NULL) {
		if (CFGetTypeID(descArray) == CFArrayGetTypeID()) {
			descCount = CFArrayGetCount(descArray);

			for (descIndex = 0; descIndex < descCount; descIndex++) {
				CFNumberRef thisDescNum;
				int 		thisDesc;
		
				thisDescNum = (CFNumberRef) CFArrayGetValueAtIndex(descArray, descIndex);
				if (   (thisDescNum == NULL) 
					|| (CFGetTypeID(thisDescNum) != CFNumberGetTypeID()) 
					|| ! CFNumberGetValue(thisDescNum, kCFNumberIntType, &thisDesc) ) {
					assert(false);
				} else {
					assert(thisDesc >= 0);
					junk = close(thisDesc);
					assert(junk == 0);
				}
			}
		} else {
			assert(false);
		}
	}
}

static int BASReadDictioanaryTranslatingDescriptors(int fd, CFDictionaryRef *dictPtr)
	// Reads a dictionary and its associated descriptors (if any) from fd, 
	// putting the dictionary (modified to include the translated descriptor 
	// numbers) in *dictPtr.
    //
    // On success, the caller is responsible for releasing *dictPtr and for 
    // closing any descriptors it references (BASCloseDescriptorArray makes 
    // the second part easy).
{
	int 				err;
	int 				junk;
	CFDictionaryRef		dict;
	CFArrayRef 			incomingDescs;
	
    // Pre-conditions

	assert(fd >= 0);
	assert( dictPtr != NULL);
	assert(*dictPtr == NULL);
	
	dict = NULL;
	
	// Read the dictionary.
	
	err = BASReadDictionary(fd, &dict);
	
	// Now read the descriptors, if any.
	
	if (err == 0) {
		incomingDescs = (CFArrayRef) CFDictionaryGetValue(dict, CFSTR(kBASDescriptorArrayKey));
		if (incomingDescs == NULL) {
			// No descriptors.  Not much to do.  Just use dict as the response, 
            // NULLing it out so that we don't release it at the end.
			
			*dictPtr = dict;
			dict = NULL;
		} else {
			CFMutableArrayRef 		translatedDescs;
			CFMutableDictionaryRef	mutableDict;
			CFIndex					descCount;
			CFIndex					descIndex;
			
			// We have descriptors, so there's lots of stuff to do.  Have to 
			// receive each of the descriptors assemble them into the 
			// translatedDesc array, then create a mutable dictionary based 
			// on response (mutableDict) and replace the 
			// kBASDescriptorArrayKey with translatedDesc.
			
			translatedDescs  = NULL;
			mutableDict      = NULL;

			// Start by checking incomingDescs.
					
			if ( CFGetTypeID(incomingDescs) != CFArrayGetTypeID() ) {
				err = EINVAL;
			}
			
			// Create our output data.
			
			if (err == 0) {
                translatedDescs = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
                if (translatedDescs == NULL) {
                    err = coreFoundationUnknownErr;
                }
			}
			if (err == 0) {
				mutableDict = CFDictionaryCreateMutableCopy(NULL, 0, dict);
				if (mutableDict == NULL) {
					err = BASOSStatusToErrno( coreFoundationUnknownErr );
				}
			}

			// Now read each incoming descriptor, appending the results 
			// to translatedDescs as we go.  By keeping our working results 
			// in translatedDescs, we make sure that we can clean up if 
			// we fail.
			
			if (err == 0) {
				descCount = CFArrayGetCount(incomingDescs);
				
				// We don't actually depend on the descriptor values in the 
				// response (that is, the elements of incomingDescs), because 
				// they only make sense it the context of the sending process. 
				// All we really care about is the number of elements, which 
				// tells us how many times to go through this loop.  However, 
				// just to be paranoid, in the debug build I check that the 
				// incoming array is well formed.

				#if !defined(NDEBUG)
					for (descIndex = 0; descIndex < descCount; descIndex++) {
						int 		thisDesc;
						CFNumberRef thisDescNum;
						
						thisDescNum = (CFNumberRef) CFArrayGetValueAtIndex(incomingDescs, descIndex);
						assert(thisDescNum != NULL);
						assert(CFGetTypeID(thisDescNum) == CFNumberGetTypeID());
						assert(CFNumberGetValue(thisDescNum, kCFNumberIntType, &thisDesc));
						assert(thisDesc >= 0);
					}
				#endif
				
				// Here's the real work.  For descCount times, read a descriptor 
				// from fd, wrap it in a CFNumber, and append it to translatedDescs. 
				// Note that we have to be very careful not to leak a descriptor 
				// if we get an error here.
				
				for (descIndex = 0; descIndex < descCount; descIndex++) {
					int 		thisDesc;
					CFNumberRef thisDescNum;
					
					thisDesc = -1;
					thisDescNum = NULL;
					
					err = BASReadDescriptor(fd, &thisDesc);
					if (err == 0) {
						thisDescNum = CFNumberCreate(NULL, kCFNumberIntType, &thisDesc);
						if (thisDescNum == NULL) {
							err = BASOSStatusToErrno( coreFoundationUnknownErr );
						}
					}
					if (err == 0) {
						CFArrayAppendValue(translatedDescs, thisDescNum);
						// The descriptor is now stashed in translatedDescs, 
						// so this iteration of the loop is no longer responsible 
						// for closing it.
						thisDesc = -1;		
					}
					
                    if (thisDescNum != NULL) {
                        CFRelease(thisDescNum);
                    }
					if (thisDesc != -1) {
						junk = close(thisDesc);
						assert(junk == 0);
					}
					
					if (err != 0) {
						break;
					}
				}
			}

			// Clean up and establish output parameters.
			
			if (err == 0) {
				CFDictionarySetValue(mutableDict, CFSTR(kBASDescriptorArrayKey), translatedDescs);
				*dictPtr = mutableDict;
			} else {
				BASCloseDescriptorArray(translatedDescs);
                if (mutableDict != NULL) {
                    CFRelease(mutableDict);
                }
			}
            if (translatedDescs != NULL) {
                CFRelease(translatedDescs);
            }
		}
	}
	
    if (dict != NULL) {
        CFRelease(dict);
    }
	
	assert( (err == 0) == (*dictPtr != NULL) );
	
	return err;
}

static int BASWriteDictionaryAndDescriptors(CFDictionaryRef dict, int fd)
	// Writes a dictionary and its associated descriptors to fd.
{
	int 			err;
	CFArrayRef 		descArray;
	CFIndex			descCount;
	CFIndex			descIndex;
	
    // Pre-conditions

    assert(dict != NULL);
    assert(fd >= 0);
    
	// Write the dictionary.
	
	err = BASWriteDictionary(dict, fd);
	
	// Process any descriptors.  The descriptors are indicated by 
	// a special key in the dictionary.  If that key is present, 
	// it's a CFArray of CFNumbers that present the descriptors to be 
	// passed.
	
	if (err == 0) {
		descArray = (CFArrayRef) CFDictionaryGetValue(dict, CFSTR(kBASDescriptorArrayKey));
		
		// We only do the following if the special key is present.
		
		if (descArray != NULL) {
		
			// If it's not an array, that's bad.
			
			if ( CFGetTypeID(descArray) != CFArrayGetTypeID() ) {
				err = EINVAL;
			}
			
			// Loop over the array, getting each descriptor and writing it.
			
			if (err == 0) {
				descCount = CFArrayGetCount(descArray);
				
				for (descIndex = 0; descIndex < descCount; descIndex++) {
					CFNumberRef thisDescNum;
					int 		thisDesc;
					
					thisDescNum = (CFNumberRef) CFArrayGetValueAtIndex(descArray, descIndex);
					if (   (thisDescNum == NULL) 
						|| (CFGetTypeID(thisDescNum) != CFNumberGetTypeID()) 
						|| ! CFNumberGetValue(thisDescNum, kCFNumberIntType, &thisDesc) ) {
						err = EINVAL;
					}
					if (err == 0) {
						err = BASWriteDescriptor(fd, thisDesc);
					}

					if (err != 0) {
						break;
					}
				}
			}
		}
	}

	return err;
}

static OSStatus FindCommand(
	CFDictionaryRef             request,
	const BASCommandSpec		commands[],
    size_t *                    commandIndexPtr
)
    // FindCommand is a simple utility routine for checking that the 
    // command name within a request is valid (that is, matches one of the command 
    // names in the BASCommandSpec array).
    // 
    // On success, *commandIndexPtr will be the index of the requested command 
    // in the commands array.  On error, the value in *commandIndexPtr is undefined.
{
	OSStatus					retval = noErr;
    CFStringRef                 commandStr;
    char *                      command;
	UInt32						commandSize = 0;
	size_t						index = 0;
	
	// Pre-conditions
	
	assert(request != NULL);
	assert(commands != NULL);
	assert(commands[0].commandName != NULL);        // there must be at least one command
	assert(commandIndexPtr != NULL);
    
    command = NULL;

    // Get the command as a C string.  To prevent untrusted command string from 
	// trying to run us out of memory, we limit its length to 1024 UTF-16 values.
    
    commandStr = CFDictionaryGetValue(request, CFSTR(kBASCommandKey));
    if ( (commandStr == NULL) || (CFGetTypeID(commandStr) != CFStringGetTypeID()) ) {
        retval = paramErr;
    }
	commandSize = CFStringGetLength(commandStr);
	if ( (retval == noErr) && (commandSize > 1024) ) {
		retval = paramErr;
	}
    if (retval == noErr) {
        size_t      bufSize;
        
        bufSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength(commandStr), kCFStringEncodingUTF8) + 1;
        command = malloc(bufSize);
        
        if (command == NULL) {
            retval = memFullErr;
        } else if ( ! CFStringGetCString(commandStr, command, bufSize, kCFStringEncodingUTF8) ) {
            retval = coreFoundationUnknownErr;
        }
    }
    
    // Search the commands array for that command.
    
    if (retval == noErr) {
        do {
            if ( strcmp(commands[index].commandName, command) == 0 ) {
                *commandIndexPtr = index;
                break;
            }
            index += 1;
            if (commands[index].commandName == NULL) {
                retval = BASErrnoToOSStatus(ENOENT);
                break;
            }
        } while (true);
    }

    free(command);

	return retval;
}

/////////////////////////////////////////////////////////////////
#pragma mark ***** Tool Code

/*
    Watchdog Timer
    --------------
    BetterAuthorizationSampleLib's privileged helper tool server is single threaded.  Thus, 
    it's possible for a broken or malicious client to stop progress within the helper 
    tool simply by sending the tool half a request.  The single thread of execution 
    within the tool will wait forever for the rest of the request and, while it's 
    waiting, it won't be able to service other requests.  Clearly this is not good.
    
    I contemplated a number of solutions to this problem, but eventually settled 
    on a very simple solution.  When it starts processing a request, the tool 
    starts a watchdog timer.  If the timer expires, the tool dies.  The single 
    request that the tool is blocked on will fail (because our end of the per-connection 
    socket for that request closed when we died) and subsequent requests will 
    relaunch the tool on demand, courtesy of launchd.
    
    I use SIGALRM to implement this functionality.  As stated in our header, the 
    BetterAuthorizationSampleLib code claims this signal and our clients are required not 
    to use it.  Also, the default disposition for SIGALRM is to quit the process, 
    which is exactly what I want.
*/

static void EnableWatchdog(void)
    // Start the watchdog timer.  If you don't call DisableWatchdog before the 
    // timer expires, the process will die with a SIGALRM.
{
    (void) alarm(kWatchdogTimeoutInSeconds);
}

static void DisableWatchdog(void)
    // Disable the watchdog timer.
{
    (void) alarm(0);
}

#if ! defined(NDEBUG)
    
    static bool CommandArraySizeMatchesCommandProcArraySize(
        const BASCommandSpec		commands[], 
        const BASCommandProc		commandProcs[]
    )
    {
        size_t  commandCount;
        size_t  procCount;
        
        commandCount = 0;
        while ( commands[commandCount].commandName != NULL ) {
            commandCount += 1;
        }
        
        procCount = 0;
        while ( commandProcs[procCount] != NULL ) {
            procCount += 1;
        }
        
        return (commandCount == procCount);
    }
    
#endif

/*
    On-The-'Wire' Protocol
    ----------------------
    The on-the-'wire' protocol for a BetterAuthorizationSampleLib connection (from the 
    perspective of the client) is:
    
    connect
    
    send AuthorizationExternalForm (32 byte blob)
    send request dictionary length (4 bytes, uint32_t, big endian)
    send request dictionary (N bytes, flattened CFPropertyList)

    read response dictionary length (4 bytes, uint32_t, big endian)
    read response dictionary (N bytes, flattened CFPropertyList)
    for each descriptor in dictionary
        read 1 byte ('D') with attached descriptor
        write 1 byte ('A')

    close
*/

static int HandleConnection(
    aslclient                   asl,
    aslmsg                      aslMsg,
	const BASCommandSpec		commands[], 
	const BASCommandProc		commandProcs[],
    int                         fd
)
    // This routine handles a single connection from a client.  This connection, in 
    // turn, represents a single command (request/response pair).  commands is the 
    // list of valid commands.  commandProc is a callback to call to actually 
    // execute a command.  Finally, fd is the file descriptor from which the request 
    // should be read, and to which the response should be sent.
{
    int                         retval;
    OSStatus                    junk;
    int                         junkInt;
    AuthorizationExternalForm	extAuth;
    AuthorizationRef			auth		= NULL;
    CFDictionaryRef				request		= NULL;
    size_t                      commandIndex;
    CFMutableDictionaryRef		response	= NULL;
    OSStatus                    commandProcStatus;
    
    // Pre-conditions

    // asl may be NULL
    // aslMsg may be NULL
	assert(commands != NULL);
	assert(commands[0].commandName != NULL);        // there must be at least one command
    assert(commandProcs != NULL);
    assert( CommandArraySizeMatchesCommandProcArraySize(commands, commandProcs) );
    assert(fd >= 0);
    
    // Read in the external authorization reference.
    retval = BASRead(fd, &extAuth, sizeof(extAuth), NULL);
    
    // Internalize external authorization reference.
    if (retval == 0) {
        retval = BASOSStatusToErrno( AuthorizationCreateFromExternalForm(&extAuth, &auth) );
    }
    
    // Read in CFDictionaryRef request (the command and its arguments).
    if (retval == 0) {
        retval = BASReadDictionary(fd, &request);
    }
    
    // Create a mutable response dictionary before calling the client.
    if (retval == 0) {
        response = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (response == NULL) {
            retval = BASOSStatusToErrno( coreFoundationUnknownErr );
        }
    }

    // Errors that occur within this block are considered command errors, that is, they're 
    // reported to the client in the kBASErrorKey value of the response dictionary 
    // (that is, BASExecuteRequestInHelperTool returns noErr and valid response dictionary with 
    // an error value in the kBASErrorKey entry of the dictionary).  In contrast, other errors 
    // are considered IPC errors and generally result in a the client getting an error status 
    // back from BASExecuteRequestInHelperTool.
    //
    // Notably a request with an unrecognised command string will return an error code 
    // in the response, as opposed to an IPC error.  This means that a client can check 
    // whether a tool supports a particular command without triggering an IPC teardown.
    
    if (retval == 0) {        
        // Get the command name from the request dictionary and check to see whether or 
        // not the command is valid by comparing with the BASCommandSpec array.  Also, 
        // if the command is valid, return the associated right (if any).

        commandProcStatus = FindCommand(request, commands, &commandIndex);
        
        // Acquire the associated right for the command.  If rightName is NULL, the 
		// commandProc is required to do its own authorization.
        
        if ( (commandProcStatus == noErr) && (commands[commandIndex].rightName != NULL) ) {
            AuthorizationItem   item   = { commands[commandIndex].rightName, 0, NULL, 0 };
            AuthorizationRights rights = { 1, &item };
            
            commandProcStatus = AuthorizationCopyRights(
                auth, 
                &rights, 
                kAuthorizationEmptyEnvironment, 
                kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed, 
                NULL
            );
        }
    
        // Call callback to execute command based on the request.
        
        if (commandProcStatus == noErr) {
            commandProcStatus = commandProcs[commandIndex](auth, commands[commandIndex].userData, request, response, asl, aslMsg);

            if (commandProcStatus == noErr) {
                junkInt = asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Command callback succeeded");
                assert(junkInt == 0);
            } else {
                junkInt = asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Command callback failed: %ld", (long) commandProcStatus);
                assert(junkInt == 0);
            }
        }

        // If the command didn't insert its own error value, we use its function 
        // result as the error value.
        
        if ( ! CFDictionaryContainsKey(response, CFSTR(kBASErrorKey)) ) {
            CFNumberRef     numRef;
            
            numRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &commandProcStatus);
            if (numRef == NULL) {
                retval = BASOSStatusToErrno( coreFoundationUnknownErr );
            } else {
                CFDictionaryAddValue(response, CFSTR(kBASErrorKey), numRef);
                CFRelease(numRef);
            }
        }
    }
                                                                    
    // Write response back to the client.
    if (retval == 0) {
        retval = BASWriteDictionaryAndDescriptors(response, fd);
    }
    
    // Clean up.
    
    if (response != NULL) {
        // If there are any descriptors in response, we've now passed them off to the client, 
        // so we can (and must) close our references to them.
        BASCloseDescriptorArray( CFDictionaryGetValue(response, CFSTR(kBASDescriptorArrayKey)) );
        CFRelease(response);
    }
    if (request != NULL) {
        CFRelease(request);
    }
    if (auth != NULL) {
        junk = AuthorizationFree(auth, kAuthorizationFlagDefaults);
        assert(junk == noErr);
    }
    
    return retval;
}

#if !defined(NDEBUG)

    static void WaitForDebugger(aslclient asl, aslmsg aslMsg)
        // You can force a debug version of the tool to stop and wait on 
        // launch using the following Terminal command:
        //
        // $ sudo launchctl stop com.example.BetterAuthorizationSample
        // $ sudo launchctl setenv BASWaitForDebugger 1
    {
        int         err;
        const char *value;
        
        // asl may be NULL
        // aslMsg may be NULL
        
        value = getenv("BASWaitForDebugger");
        if ( ((value != NULL) && (atoi(value) != 0)) ) {
            err = asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Waiting for debugger");
            assert(err == 0);
            (void) pause();
        }
    }

#endif

static int CheckInWithLaunchd(aslclient asl, aslmsg aslMsg, const char **errStrPtr)
    // Checks in with launchd and gets back our listening socket.  
    // Returns the socket as the function result (or -1 on error). 
    // Also, on error, set *errStrPtr to a error string suitable 
    // for logging with ASL.  If the message contains a %m, which 
	// causes ASL to log errno, errno will be set appropriately.
{
    int             err;
	launch_data_t   checkinRequest = NULL;
	launch_data_t   checkinResponse = NULL;
	launch_data_t   socketsDict;
	launch_data_t   fdArray;
    launch_data_t   fdData;
    int             fd = -1;
    
    // Pre-conditions

    // asl may be NULL
    // aslMsg may be NULL
    assert( errStrPtr != NULL);
    assert(*errStrPtr == NULL);
    
	// Check in with launchd.  Create a checkin request, then run it, then 
    // check if we got an error.
    
    checkinRequest = launch_data_new_string(LAUNCH_KEY_CHECKIN);
	if (checkinRequest == NULL) {
        *errStrPtr = "Could not create checkin request: %m";
		goto done;
	}
    checkinResponse = launch_msg(checkinRequest);
	if (checkinResponse == NULL) {
        *errStrPtr = "Error checking in: %m";
		goto done;
	}
	if (launch_data_get_type(checkinResponse) == LAUNCH_DATA_ERRNO) {
		errno = launch_data_get_errno(checkinResponse);            // set errno so %m picks it up
		*errStrPtr = "Checkin failed: %m";
		goto done;
	}
	
	// Retrieve the dictionary of sockets entries from the job.  This corresponds to the 
    // value of the "Sockets" key in our plist file.

	socketsDict = launch_data_dict_lookup(checkinResponse, LAUNCH_JOBKEY_SOCKETS);
	if (socketsDict == NULL) {
        *errStrPtr = "Could not get socket dictionary from checkin response: %m";
		goto done;
	}
	if (launch_data_get_type(socketsDict) != LAUNCH_DATA_DICTIONARY) {
        *errStrPtr = "Could not get socket dictionary from checkin response: Type mismatch";
		goto done;
	}
	if (launch_data_dict_get_count(socketsDict) > 1) {
		err = asl_log(asl, aslMsg, ASL_LEVEL_WARNING, "Some sockets in dictionary will be ignored");
        assert(err == 0);
	}
	
	// Get the dictionary value from the key "MasterSocket", as defined in the launchd 
	// property list file.

	fdArray = launch_data_dict_lookup(socketsDict, kLaunchDSocketDictKey);
	if (fdArray == NULL) {
        *errStrPtr = "Could not get file descriptor array: %m";
		goto done;
	}
	if (launch_data_get_type(fdArray) != LAUNCH_DATA_ARRAY) {
        *errStrPtr = "Could not get file descriptor array: Type mismatch";
		goto done;
	}
	if (launch_data_array_get_count(fdArray) > 1) {
		err = asl_log(asl, aslMsg, ASL_LEVEL_WARNING, "Some sockets in array will be ignored");
        assert(err == 0);
	}
	
	// Get the socket file descriptor from the array.

    fdData = launch_data_array_get_index(fdArray, 0);
    if (fdData == NULL) {
        *errStrPtr = "Could not get file descriptor array entry: %m";
		goto done;
    }
    if (launch_data_get_type(fdData) != LAUNCH_DATA_FD) {
        *errStrPtr = "Could not get file descriptor array entry: Type mismatch";
		goto done;
    }
    fd = launch_data_get_fd(fdData);
    assert(fd >= 0);

    // The following was used to debug a problem with launchd <rdar://problem/5410487>.  
    // I'm going to leave it in, disabled, until that problem is resolved.
    
    if (false) {
        err = asl_log(asl, aslMsg, ASL_LEVEL_INFO, "Listening descriptor is %d", fd);
        assert(err == 0);
    }
    
done:
    if (checkinResponse != NULL) {
        launch_data_free(checkinResponse);
    }
    if (checkinRequest != NULL) {
        launch_data_free(checkinRequest);
    }
    
    return fd;
}

static int SetNonBlocking(int fd, Boolean nonBlocking)
    // Sets the non-blocking state of fd.
{
    int     err;
    int     flags;

    // Pre-conditions

    assert(fd >= 0);

    // Get the flags.
    
    err = 0;
    flags = fcntl(fd, F_GETFL);
    if (flags < 0) {
        err = errno;
    }
    
    // If the current state of O_NONBLOCK doesn't match the required 
    // state, toggle that flag and set it back.
    
    if ( (err == 0) && (((flags & O_NONBLOCK) != 0) != nonBlocking) ) {
        flags ^= O_NONBLOCK;
        err = fcntl(fd, F_SETFL, flags);
        if (err < 0) {
            err = errno;
        }
    }
    
    return err;
}

extern int BASHelperToolMain(
	const BASCommandSpec		commands[], 
	const BASCommandProc		commandProcs[]
)
    // See comment in header.
{
    const char *                errStr = NULL;
    int                         err;
	aslclient					asl = NULL;
	aslmsg						aslMsg = NULL;
	sig_t						pipeSet;
    int                         listener;
	int							kq;
	struct kevent				initEvent;
	
	// Pre-conditions
	
	assert(commands != NULL);
	assert(commands[0].commandName != NULL);        // there must be at least one command
	assert(commandProcs != NULL);
    assert( CommandArraySizeMatchesCommandProcArraySize(commands, commandProcs) );
	
	// Create a new ASL client object, and a template message for any messages that 
    // we log.  We don't care if these fail because ASL will do the right thing 
    // if you pass it NULL (that is, nothing).
    
	asl     = asl_open(NULL, "HelperTools", ASL_OPT_STDERR);
    assert(asl != NULL);
    
	aslMsg = asl_new(ASL_TYPE_MSG);
    assert(aslMsg != NULL);

    err = asl_log(asl, aslMsg, ASL_LEVEL_INFO, "Starting up");
    assert(err == 0);

    #if !defined(NDEBUG)
        WaitForDebugger(asl, aslMsg);
    #endif
    	
	// Set up the signal handlers we are interested in.
    //
    // o SIGTERM -- launchd sends us this when it wants us to quit.  We don't 
	//   actually need to set up a handler because the default behaviour (process 
    //   termination) is fine.
    //
    // o SIGALRM -- No need to set it up because the default behaviour (process 
    //   termination) is fine.  See the "Watchdog Timer" comment (above) for details.
    //
    // o SIGPIPE -- We don't want to quit when write to a dead socket, so we 
    //   ignore this signal.
	
    pipeSet = signal(SIGPIPE, SIG_IGN);
    if (pipeSet == SIG_ERR) {
        errStr = "Could not ignore SIGPIPE: %m";
        goto done;
    }
	
    // Check in with launchd and get our listening socket.
    
    listener = CheckInWithLaunchd(asl, aslMsg, &errStr);
    if (listener < 0) {
        assert(errStr != NULL);
        goto done;
    }

    // Create a kqueue and wrap the listening socket in it.

    kq = kqueue();
	if (kq < 0) {
        errStr = "Could not create kqueue: %m";
		goto done;
	}

    EV_SET(&initEvent, listener, EVFILT_READ, EV_ADD, 0, 0, NULL);
    err = kevent(kq, &initEvent, 1, NULL, 0, NULL);
    if (err < 0) {
        errStr = "Could not add listening socket to kqueue: %m";
        goto done;
    }
	
    // Force the listening socket to non-blocking mode.  Without this, our timeout 
    // handling won't work properly.  Specifically, we could get stuck in an accept 
    // if a connection request appears and then disappears.  Eventually the watchdog 
    // would clean up, but that's not a great solution.

    err = SetNonBlocking(listener, true);
    if (err != 0) {
        errno = err;            // for %m
        errStr = "Could not check/set socket flags: %m";
        goto done;
    }
    
	// Loop servicing connection requests one at a time.
    
    while (true) {
        int                         eventCount;
        struct kevent               thisEvent;
		int                         thisConnection;
        int                         thisConnectionError;
        struct sockaddr_storage     clientAddr;         // we don't need this info, but accept won't let us ignore it
        socklen_t                   clientAddrLen = sizeof(clientAddr);
        static const struct timespec kIdleTimeout = { kIdleTimeoutInSeconds , 0 };
        
		// Wait on the kqueue for a connection request.

        eventCount = kevent(kq, NULL, 0, &thisEvent, 1, &kIdleTimeout);
        if (eventCount == 0) {
            // We've hit our idle timer.  Just break out of the connection loop.
            break;
        } else if (eventCount == -1) {
            // We got some sort of error from kevent; quit with an error.
            errStr = "Unexpected error while listening for connections: %m";
            goto done;
        }

        // From this point on, we're running on the watchdog timer.  If we get 
        // stuck anywhere, the watchdog will fire eventually and we'll quit.
        
        EnableWatchdog();
		
        // The accept should never get stuck because this is a non-blocking 
        // socket.
        
        thisConnection = accept(thisEvent.ident, (struct sockaddr *) &clientAddr, &clientAddrLen);
        if (thisConnection == -1) {
            if (errno == EWOULDBLOCK) {
                // If the incoming connection just disappeared (perhaps the client 
                // died before we accepted the connection), don't log that as an error 
                // and don't quit.
                err = asl_log(asl, aslMsg, ASL_LEVEL_INFO, "Connection disappeared before we could accept it: %m");
                assert(err == 0);
            } else {
                // Other errors mean that we're in a very weird state; we respond by 
                // failing out with an error.
                errStr = "Unexpected error while accepting a connection: %m";
                goto done;
            }
        }

        // Because the accept can fail in a non-fatal fashion, thisConnection can be 
        // -1 here.  In that case, we just skip the next step.

        if (thisConnection != -1) {
            err = asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Request started");
            assert(err == 0);
            
            // thisConnection inherits its non-blocking setting from listener, but 
            // we want it to be blocking from here on in, so we switch the status.  
            // We're now relying on the watchdog to kill us if we get stuck.
            
            thisConnectionError = BASErrnoToOSStatus( SetNonBlocking(thisConnection, false) );

            // Entering heavy liftiing.  We have a separate routine to actually 
            // read the request from the connection, call the client, and send 
            // the reply.

            if (thisConnectionError == noErr) {
                thisConnectionError = HandleConnection(asl, aslMsg, commands, commandProcs, thisConnection);
            }

            err = close(thisConnection);
            assert(err == 0);

            if (thisConnectionError == 0) {
                err = asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Request finished");
            } else {
                errno = thisConnectionError;            // so it can be picked up by %m
                err = asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Request failed: %m");
            }
            assert(err == 0);
        }

        DisableWatchdog();
	}
	
done:
    // At this point, errStr is either NULL, in which case we're quitting because 
    // of our idle timer, or non-NULL, in which case we're dying with an error.
    
    // We expect the caller to immediately quit once we return.  Thus, we 
    // don't bother cleaning up any resources we have allocated here, including 
    // asl, aslMsg, and kq.
    
    if (errStr != NULL) {
        err = asl_log(asl, aslMsg, ASL_LEVEL_ERR, errStr);
        assert(err == 0);
    }
    err = asl_log(asl, aslMsg, ASL_LEVEL_INFO, "Shutting down");
    assert(err == 0);
    return (errStr == NULL) ? EXIT_SUCCESS : EXIT_FAILURE;
}

/////////////////////////////////////////////////////////////////
#pragma mark ***** App Code

extern void BASSetDefaultRules(
	AuthorizationRef			auth,
	const BASCommandSpec		commands[],
	CFStringRef					bundleID,
	CFStringRef					descriptionStringTableName
)
    // See comment in header.
{	
	OSStatus					err;
    CFBundleRef                 bundle;
	size_t						commandIndex;
	
	// Pre-conditions
	
	assert(auth != NULL);
	assert(commands != NULL);
	assert(commands[0].commandName != NULL);        // there must be at least one command
	assert(bundleID != NULL);
    // descriptionStringTableName may be NULL
    
    bundle = CFBundleGetBundleWithIdentifier(bundleID);
    assert(bundle != NULL);
	
    // For each command, set up the default authorization right specification, as 
    // indicated by the command specification.
    
    commandIndex = 0;
    while (commands[commandIndex].commandName != NULL) {
        // Some no-obvious assertions:
        
        // If you have a right name, you must supply a default rule.
        // If you have no right name, you can't supply a default rule.

        assert( (commands[commandIndex].rightName == NULL) == (commands[commandIndex].rightDefaultRule == NULL) );

        // If you have no right name, you can't supply a right description.
        // OTOH, if you have a right name, you may supply a NULL right description 
        // (in which case you get no custom prompt).

        assert( (commands[commandIndex].rightName != NULL) || (commands[commandIndex].rightDescriptionKey == NULL) );
        
        // If there's a right name but no current right specification, set up the 
        // right specification.
        
        if (commands[commandIndex].rightName != NULL) {
            err = AuthorizationRightGet(commands[commandIndex].rightName, (CFDictionaryRef*) NULL);
            if (err == errAuthorizationDenied) {
                CFStringRef thisDescription;
                CFStringRef	thisRule;
                
                // The right is not already defined.  Set up a definition based on 
                // the fields in the command specification.
                
                thisRule = CFStringCreateWithCString(
                    kCFAllocatorDefault, 
                    commands[commandIndex].rightDefaultRule, 
                    kCFStringEncodingUTF8
                );
                assert(thisRule != NULL);
                
                thisDescription = NULL;
                if (commands[commandIndex].rightDescriptionKey != NULL) {
                    thisDescription = CFStringCreateWithCString (
                        kCFAllocatorDefault, 
                        commands[commandIndex].rightDescriptionKey, 
                        kCFStringEncodingUTF8
                    );
                    assert(thisDescription != NULL);
                }
                
                err = AuthorizationRightSet(
                    auth,										// authRef
                    commands[commandIndex].rightName,           // rightName
                    thisRule,                                   // rightDefinition
                    thisDescription,							// descriptionKey
                    bundle,                                     // bundle
                    descriptionStringTableName					// localeTableName
                );												// NULL indicates "Localizable.strings"
                assert(err == noErr);
                
                if (thisDescription != NULL) {
					CFRelease(thisDescription);
				}
                if (thisRule != NULL) {
					CFRelease(thisRule);
				}
            } else { 
                // A right already exists (err == noErr) or any other error occurs, we 
                // assume that it has been set up in advance by the system administrator or
                // this is the second time we've run.  Either way, there's nothing more for 
                // us to do.
            }
        }
        commandIndex += 1;
	}
}

extern OSStatus BASExecuteRequestInHelperTool(
	AuthorizationRef			auth,
	const BASCommandSpec		commands[],
	CFStringRef					bundleID,
	CFDictionaryRef				request,
	CFDictionaryRef *			response
)
    // See comment in header.
{	
	OSStatus					retval = noErr;
    int                         junk;
    size_t                      commandIndex;
    char                        bundleIDC[PATH_MAX];
	int							fd = -1;
	struct sockaddr_un			addr;
	AuthorizationExternalForm	extAuth;
	
	// Pre-conditions
	
	assert(auth != NULL);
	assert(commands != NULL);
	assert(commands[0].commandName != NULL);        // there must be at least one command
	assert(bundleID != NULL);
	assert(request != NULL);
	assert( response != NULL);
	assert(*response == NULL);
    
	// For debugging.

	assert(CFDictionaryContainsKey(request, CFSTR(kBASCommandKey)));
	assert(CFGetTypeID(CFDictionaryGetValue(request, CFSTR(kBASCommandKey))) == CFStringGetTypeID());

    // Look up the command and preauthorize.  This has the nice side effect that 
    // the authentication dialog comes up, in the typical case, here, rather than 
    // in the helper tool.  This is good because the helper tool is global /and/ 
    // single threaded, so if it's waiting for an authentication dialog for user A 
    // it can't handle requests from user B.
    
    retval = FindCommand(request, commands, &commandIndex);

    #if !defined(BAS_PREAUTHORIZE)
        #define BAS_PREAUTHORIZE 1
    #endif
    #if BAS_PREAUTHORIZE
        if ( (retval == noErr) && (commands[commandIndex].rightName != NULL) ) {
            AuthorizationItem   item   = { commands[commandIndex].rightName, 0, NULL, 0 };
            AuthorizationRights rights = { 1, &item };
            
            retval = AuthorizationCopyRights(auth, &rights, kAuthorizationEmptyEnvironment, kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize, NULL);
        }
    #endif

    // Create the socket and tell it to not generate SIGPIPE.
    
	if (retval == noErr) {
		fd = socket(AF_UNIX, SOCK_STREAM, 0);
		if (fd == -1) { 
			retval = BASErrnoToOSStatus(errno);
		}
	}
	if (retval == noErr) {
		static const int kOne = 1;
		
		if ( setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &kOne, sizeof(kOne)) < 0 ) {
			retval = BASErrnoToOSStatus(errno);
		}
	}
    
    // Form the socket address, including a path based on the bundle ID.
	
	if (retval == noErr) {
        if ( ! CFStringGetFileSystemRepresentation(bundleID, bundleIDC, sizeof(bundleIDC)) ) {
            retval = coreFoundationUnknownErr;
        }
    }
    if (retval == noErr) {
        int         pathLen;
        
		memset(&addr, 0, sizeof(addr));
	
		addr.sun_family = AF_UNIX;
        pathLen = snprintf(addr.sun_path, sizeof(addr.sun_path), kBASSocketPathFormat, bundleIDC);
        if (pathLen >= sizeof(addr.sun_path)) {
            retval = paramErr;                  // length of bundle pushed us over the UNIX domain socket path length limit
        } else {
			addr.sun_len = SUN_LEN(&addr);
		}
    }
    
    // Attempt to connect.
    
    if (retval == noErr) {
		if (connect(fd, (struct sockaddr *) &addr, sizeof(addr)) == -1) {
			retval = BASErrnoToOSStatus(errno);
		}
	}
	
    // Send the flattened AuthorizationRef to the tool.
    
    if (retval == noErr) {
        retval = AuthorizationMakeExternalForm(auth, &extAuth);
    }
	if (retval == noErr) {	
		retval = BASErrnoToOSStatus( BASWrite(fd, &extAuth, sizeof(extAuth), NULL) );
	}
	
    // Write the request.
    
	if (retval == noErr) {	
		retval = BASErrnoToOSStatus( BASWriteDictionary(request, fd) );
	}
	
    // Read response, including any descriptors.
    
	if (retval == noErr) {
		retval = BASErrnoToOSStatus( BASReadDictioanaryTranslatingDescriptors(fd, response) );
    }
    
    // Clean up.

    if (fd != -1) {
        junk = close(fd);
        assert(junk == 0);
    }
    NormaliseOSStatusErrorCode(&retval);
    
    assert( (retval == noErr) == (*response != NULL) );
    
	return retval;
}

extern OSStatus BASGetErrorFromResponse(CFDictionaryRef response)
    // See comment in header.
{
	OSStatus	err;
	CFNumberRef num;
	
	assert(response != NULL);
	
	num = (CFNumberRef) CFDictionaryGetValue(response, CFSTR(kBASErrorKey));
    err = noErr;
    if ( (num == NULL) || (CFGetTypeID(num) != CFNumberGetTypeID()) ) {
        err = coreFoundationUnknownErr;
    }
	if (err == noErr) {
		if ( ! CFNumberGetValue(num, kCFNumberSInt32Type, &err) ) {
            err = coreFoundationUnknownErr;
        }
	}
	
    NormaliseOSStatusErrorCode(&err);
	return err;
}

extern BASFailCode BASDiagnoseFailure(
	AuthorizationRef			auth,
	CFStringRef					bundleID
)
    // See comment in header.
{	
    BASFailCode                 retval = kBASFailUnknown;
    int                         err;
    int                         pathLen;
    char                        bundleIDC   [ PATH_MAX ];
	char						toolPath	[ PATH_MAX ];
	char						plistPath	[ PATH_MAX ];
		
	struct stat					fileStatus;
	int							toolErr; 
	int							plistErr;
	int							fd;
	struct sockaddr_un			addr;
	
	// Pre-conditions
	
	assert(auth != NULL);
	assert(bundleID != NULL);
	
    // Construct paths to the tool and plist.
    
    if ( CFStringGetFileSystemRepresentation(bundleID, bundleIDC, sizeof(bundleIDC)) ) {

        pathLen = snprintf(toolPath,  sizeof(toolPath),  kBASToolPathFormat,  bundleIDC);
        assert(pathLen < PATH_MAX);         // snprintf truncated the string; won't crash us, but we want to know

        pathLen = snprintf(plistPath, sizeof(plistPath), kBASPlistPathFormat, bundleIDC);
        assert(pathLen < PATH_MAX);         // snprintf truncated the string; won't crash us, but we want to know
        
        // Check if files exist at those paths.
        
        toolErr  = stat(toolPath,  &fileStatus);
        plistErr = stat(plistPath, &fileStatus);
        
        if ( (toolErr == 0) && (plistErr == 0) ) {
            // If both items are present, try to connect and see what we get.
            
            fd = socket(AF_UNIX, SOCK_STREAM, 0);
            if (fd != -1) { 
                memset(&addr, 0, sizeof(addr));
            
                addr.sun_family = AF_UNIX;
                (void) snprintf(addr.sun_path, sizeof(addr.sun_path), kBASSocketPathFormat, bundleIDC);
				addr.sun_len    = SUN_LEN(&addr);
            
                // Attempt to connect to the socket.  If we get ECONNREFUSED, it means no one is 
                // listening.
                
                if ( (connect(fd, (struct sockaddr *) &addr, sizeof(addr)) == -1) && (errno == ECONNREFUSED) ) {
                    retval = kBASFailDisabled;
                }
                err = close(fd);
                assert(err == 0);
            }
        } else {
            if ( (toolErr == 0) || (plistErr == 0) ) {
                retval = kBASFailPartiallyInstalled;
            } else {
                retval = kBASFailNotInstalled;
            }
        }
    }
	
	return retval;
}

// kPlistTemplate is a template for our launchd.plist file.

static const char * kPlistTemplate =
    // The standard plist header.
    
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
    "<plist version=\"1.0\">\n"
    "<dict>\n"

    // We install the job disabled, then enable it as the last step.

    "	<key>Disabled</key>\n"
    "	<true/>\n"

    // Use the bundle identifier as the job label.

    "	<key>Label</key>\n"
    "	<string>%s</string>\n"

    // Use launch on demaind.

    "	<key>OnDemand</key>\n"
    "	<true/>\n"

    // There are no program arguments, other that the path to the helper tool itself.
    //
    // IMPORTANT
    // kBASToolPathFormat embeds a %s

    "	<key>ProgramArguments</key>\n"
    "	<array>\n"
    "		<string>" kBASToolPathFormat "</string>\n"
    "	</array>\n"

    // The tool is required to check in with launchd.

    "	<key>ServiceIPC</key>\n"
    "	<true/>\n"

    // This specifies the UNIX domain socket used to launch the tool, including 
    // the permissions on the socket (438 is 0666).
    //
    // IMPORTANT
    // kBASSocketPathFormat embeds a %s

    "	<key>Sockets</key>\n"
    "	<dict>\n"
    "		<key>" kLaunchDSocketDictKey "</key>\n"
    "		<dict>\n"
    "			<key>SockFamily</key>\n"
    "			<string>Unix</string>\n"
    "			<key>SockPathMode</key>\n"
    "			<integer>438</integer>\n"
    "			<key>SockPathName</key>\n"
    "			<string>" kBASSocketPathFormat "</string>\n"
    "			<key>SockType</key>\n"
    "			<string>Stream</string>\n"
    "		</dict>\n"
    "	</dict>\n"
    "</dict>\n"
    "</plist>\n"
    ;
	

//  Installation
//  ------------
//  We install by running our "InstallTool" using AuthorizationExecuteWithPrivileges 
//  (AEWP) and passing the relevant parameters to it through AEWP.
//    
//  There is an obvious issue with the way we are handling installation as the user
//  is executing some non-privileged code by way of AEWP. The scenario could exist 
//  that the code is malicious (or they have other malicious code running at the 
//  same time) and it could swap in any other tool that it would want executed as 
//  EUID == 0.
//    
//  We decided on this design primarily because the only other option was to run a 
//  shell via AEWP and pipe a script to it. That would have given us the nice 
//  properties of not having to have a separate installer on disk and the script 
//  could be embedded within the executable making it a little more difficult for 
//  casual hacking. 
//    
//  However, running a shell as root is /not/ a very good paradigm to follow, thus, 
//  weighing the cost-benefits from a security perspective impelled us to just use 
//  a separate installer tool. The assumption being that, no matter what, if a user 
//  has malicious code running on their system the added security of having an 
//  embedded script is negligible and not worth pulling in an entire shell 
//  environment as root.
//  
//  The obvious disadvantages stem from the first advantage of the former, namely,
//  it's a little more coding and accounting effort (-:
//
//
//  What's This About Zombies?
//  --------------------------
//  AuthorizationExecuteWithPrivileges creates a process that runs with privileges. 
//  This process is a child of our process.  Thus, we need to reap the process 
//  (by calling <x-man-page://2/waitpid>).  If we don't do this, we create a 'zombie' 
//  process (<x-man-page://1/ps> displays its status as "Z") that persists until 
//  our process quits (at which point the zombie gets reparented to launchd, and 
//  launchd automatically reaps it).  Zombies are generally considered poor form. 
//  Thus, we want to avoid creating them.
//
//  Unfortunately, AEWP doesn't return the process ID of the child process 
//  <rdar://problem/3090277>, which makes it challenging for us to reap it.  We could 
//  reap all children (by passing -1 to waitpid) but that's not cool for library code 
//  (we could end up reaping a child process that's completely unrelated to this 
//  code, perhaps created by some other part of the host application).  Thus, we need 
//  to find the child process's PID.  And the only way to do that is for the child 
//  process to tell us.
//
//  So, in the child process (the install tool) we echo the process ID and in the 
//  parent we look for that in the returned text.  *sigh*  It's pretty ugly, but 
//  that's the best I can come up with.  We delimit the process ID with some 
//  pretty distinctive text to make it clear that we've got the right thing.

#if !defined(NDEBUG)

    static Boolean gBASLogInteractions = false;
        // Set gBASLogInteractions to have BASFixFailure log its interactions with 
        // the installation tool to stderr.

    static Boolean gBASLogInteractionsInitialised = false;
        // This indicates whether we've initialised gBASLogInteractions from the 
		// environment variable.

#endif

static OSStatus RunInstallToolAsRoot(
	AuthorizationRef			auth, 
    const char *                installToolPath,
	const char *				command, 
								...
)
    // Run the specified install tool as root.  The arguments to the tool are 
    // given as a sequence of (char *)s, terminated be a NULL.  The tool is 
    // expected to output special tokens to indicate success or failure.
{
    OSStatus    retval;
    size_t      argCount;
    size_t      argIndex;
    va_list     ap;
    char **     args;
    Boolean     success;
    FILE *      channel;
    int         junk;
	pid_t		childPID;

    // Pre-conditions
    
    assert(auth != NULL);
    assert(installToolPath != NULL);
    assert(command != NULL);
    
    channel = NULL;
    args    = NULL;
	childPID = -1;
    
    // Count the number of arguments.
    
    argCount = 0;
    va_start(ap, command);
    while ( va_arg(ap, char *) != NULL ) {
        argCount += 1;
    }
    va_end(ap);

    // Allocate an argument array and populate it, checking each argument along the way.
    
    retval = noErr;
    args = calloc(argCount + 3, sizeof(char *));        // +3 for installToolPath, command and trailing NULL
    if (args == NULL) {
        retval = memFullErr;
    }
    if (retval == noErr) {
        argIndex = 0;

        args[argIndex] = (char *) installToolPath;  // Annoyingly, AEWP (and exec) takes a (char * const *) 
        argIndex += 1;                              // argument, implying that it might modify the individual 
        args[argIndex] = (char *) command;          // strings.  That means you can't pass a (const char *) to 
        argIndex += 1;                              // the routine.  However, AEWP never modifies its input 
                                                    // arguments, so we just cast away the const.
                                                    // *sigh* <rdar://problem/3090294>
        va_start(ap, command);
        do {
            args[argIndex] = va_arg(ap, char *);
            if (args[argIndex] == NULL) {
                break;
            }
            argIndex += 1;
        } while (true);
        va_end(ap);
    }
    
    // Go go gadget AEWP!
    
    if (retval == noErr) {
        #if !defined(NDEBUG)
			if ( ! gBASLogInteractionsInitialised ) {
				const char *	value;
				
				value = getenv("BASLogInteractions");
				gBASLogInteractions = ( ((value != NULL) && (atoi(value) != 0)) );
				
				gBASLogInteractionsInitialised = true;
			}
		
            if (gBASLogInteractions) {
                argIndex = 0;
                while (args[argIndex] != NULL) {
                    fprintf(stderr, "args[%zd] = %s\n", argIndex, args[argIndex]);
                    argIndex += 1;
                }
            }
        #endif
        retval = AuthorizationExecuteWithPrivileges(auth, args[0], kAuthorizationFlagDefaults, &args[1], &channel);
    }
    
    // Process the tool's output.  We read every line of output from the tool until
	// we receive either an EOF or the success or failure tokens.
    //
    // AEWP provides us with no way to get to the tool's stderr or exit status, 
    // so we rely on the tool to send us this "oK" to indicate successful completion.

    if (retval == noErr) {
        char	thisLine[1024];
		long	tmpLong;
        int     tmpInt;

        // This loops is a little more complex than you might expect.  There are 
        // a number of reasons for this:
        //
        // o AEWP does not return us the child PID, so we have to scan the tool's 
        //   output look for a line that contains that information (surrounded 
        //   by special tokens).
        //
        // o Because we can't be guaranteed to get the child PID, we can't be 
        //   guaranteed to get the child's exit status.  Thus, rather than relying 
        //   on the exit status, we have the child explicitly print special tokens 
        //   on success and failure.
        //
        // o Because we're parsing special tokens anyway, we might as well extract 
        //   the real error code from the failure token.
        //
        // o A change made to launchctl in Mac OS X 10.4.7 <rdar://problem/4389914> 
        //   causes it to fork a copy of itself.  The forked copy then delays 
        //   for 30 seconds before doing some stuff, eventually printing a message 
        //   like "Workaround Bonjour: 0".  This causes us two problems.
        //
        //	 1.	The second copy of launchd still has our communications channel 
        //		(that is, the other end of "channel") as its stdin/stdout. 
        //		Thus, we don't get an EOF on channel until that copy quits. 
        //		This causes a 30 second delay in installation.
        //
        //	 2.	The second copy of launchd prints its status line (that is, 
        //		"Workaround Bonjour: 0") well after the tool prints the success 
        //      token.
        //
        //   I solved these problems by parsing each line for the success or failure 
        //   token and ignoring any output after that.
        //
        // To minimise the danger of interpreting one of the tool's commands 
        // output as one of our tokens, I've given them a wacky case (for example, 
        // "oK", not "ok" or "OK" or "Ok").
        
        do {
            success = (fgets(thisLine, sizeof(thisLine), channel) != NULL);
            if ( ! success ) {
                // We hit the end of the output without seeing a success or failure 
                // token.  Note good.  errState is an ADSP error code, but it says 
                // exactly what I want to say and it's not likely to crop up any 
                // other way.
                retval = errState;
                break;
            }
            
            // This echo doesn't work properly if the line coming back from the tool 
            // is longer than the line buffer.  However, as the echo is only relevant for 
            // debugging, and the detection of the "oK" isn't affected by this problem, 
            // I'm going to leave it as it is.
            
            #if !defined(NDEBUG)
                if (gBASLogInteractions) {
                    fprintf(stderr, ">%s", thisLine);
                }
            #endif
			
            // Look for the success token and terminate with no error in that case.
            
			if (strcmp(thisLine, kBASInstallToolSuccess "\n") == 0) {
                assert(retval == noErr);
				break;
			}
            
            // Look for the failure token and extract the error result from that.
            
            if ( sscanf(thisLine, kBASInstallToolFailure "\n", &tmpInt) == 1 ) {
                retval = BASErrnoToOSStatus( tmpInt );
                if (retval == noErr) {
                    assert(false);
                    retval = errState;
                }
                break;
            }
			
			// If we haven't already found a child process ID, look for a line 
            // that contains it (surrounded by special tokens).  For details, see 
            // the discussion of zombies above.
			
			if ( (childPID == -1) && (sscanf(thisLine, kBASAntiZombiePIDToken1 "%ld" kBASAntiZombiePIDToken2 "\n", &tmpLong) == 1) ) {
				childPID = (pid_t) tmpLong;
			}
        } while (true);
    }
	
	// If we successfully managed to determine the PID of our child process, reap 
	// that child.  Note that we ignore any errors from this step.  If an error 
	// occurs, we end up creating a zombie, which isn't too big a deal.  We also 
    // junk the status result from the tool, relying exclusively on the presence 
    // of the "oK" in the output.
	
	#if !defined(NDEBUG)
		if (gBASLogInteractions) {
			fprintf(stderr, "childPID=%ld\n", (long) childPID);
		}
	#endif
	if (childPID != -1) {
		pid_t	waitResult;
		int		junkStatus;
		
		do {
			waitResult = waitpid(childPID, &junkStatus, 0);
		} while ( (waitResult < 0) && (errno == EINTR) );
	}
    
    // Clean up.
    
    if (channel != NULL) {
        junk = fclose(channel);
        assert(junk == 0);
    }
    free(args);

    NormaliseOSStatusErrorCode(&retval);
    return retval;
}

static OSStatus BASInstall(
	AuthorizationRef			auth, 
	const char *				bundleID, 
    const char *                installToolPath,
    const char *                helperToolPath
)
	// Do an install from scratch.  Get the specified tool from the bundle 
    // and install it in the "/Library/PrivilegedHelperTools" directory, 
	// along with a plist in "/Library/LaunchDaemons".
{
    OSStatus    retval;
    int         junk;
    char *      plistText;
    int         fd;
    char        plistPath[PATH_MAX];

    // Pre-conditions
    
    assert(auth != NULL);
    assert(bundleID != NULL);
    assert(installToolPath != NULL);
    assert(helperToolPath != NULL);

    // Prepare for failure
    
    plistText = NULL;
    fd = -1;
    plistPath[0] = 0;

    // Create the property list from the template, substituting the bundle identifier in 
    // three different places.  I realise that this isn't very robust (if you change 
    // the template you have to change this code), but it is /very/ easy.
    
    retval = asprintf(&plistText, kPlistTemplate, bundleID, bundleID, bundleID);
    if (retval < 0) {
        retval = memFullErr;
    } else {
        retval = noErr;
    }
    
    // Write the plist to a temporary file.

    if (retval == noErr) {
        strlcpy(plistPath, "/tmp/BASTemp-XXXXXXXX.plist", sizeof(plistPath));
        
        fd = mkstemps(plistPath, strlen( strrchr(plistPath, '.') ) );
        if (fd < 0) {
            retval = BASErrnoToOSStatus( errno );
        }
    }
    if (retval == noErr) {
        retval = BASErrnoToOSStatus( BASWrite(fd, plistText, strlen(plistText), NULL) );
    }
    
    // Run the tool as root using AuthorizationExecuteWithPrivileges.
    
    if (retval == noErr) {
        retval = RunInstallToolAsRoot(auth, installToolPath, kBASInstallToolInstallCommand, bundleID, helperToolPath, plistPath, NULL);
    }

    // Clean up.
    
    free(plistText);
    if (fd != -1) {
        junk = close(fd);
        assert(junk == 0);
        
        junk = unlink(plistPath);
        assert(junk == 0);
    }

    return retval;
}

static OSStatus GetToolPath(CFStringRef bundleID, CFStringRef toolName, char *toolPath, size_t toolPathSize)
    // Given a bundle identifier and the name of a tool embedded within that bundle, 
    // get a file system path to the tool.
{
    OSStatus    err;
    CFBundleRef bundle;
    Boolean     success;
    CFURLRef    toolURL;
    
    assert(bundleID != NULL);
    assert(toolName != NULL);
    assert(toolPath != NULL);
    assert(toolPathSize > 0);
    
    toolURL = NULL;
    
    err = noErr;
    bundle = CFBundleGetBundleWithIdentifier(bundleID);
    if (bundle == NULL) {
        err = coreFoundationUnknownErr;
    }
    if (err == noErr) {
        toolURL = CFBundleCopyAuxiliaryExecutableURL(bundle, toolName);
        if (toolURL == NULL) {
            err = coreFoundationUnknownErr;
        }
    }
    if (err == noErr) {
        success = CFURLGetFileSystemRepresentation(toolURL, true, (UInt8 *) toolPath, toolPathSize);
        if ( ! success ) {
            err = coreFoundationUnknownErr;
        }
    }
    
    if (toolURL != NULL) {
        CFRelease(toolURL);
    }
    
    return err;
}

extern OSStatus BASFixFailure(
	AuthorizationRef			auth,
	CFStringRef					bundleID,
	CFStringRef					installToolName,
	CFStringRef					helperToolName,
	BASFailCode					failCode
)
    // See comment in header.
{	
	OSStatus    retval;
    Boolean     success;
    char        bundleIDC[PATH_MAX];
    char        installToolPath[PATH_MAX];
    char        helperToolPath[PATH_MAX];

    // Pre-conditions
    
    assert(auth != NULL);
    assert(bundleID != NULL);
    assert(installToolName != NULL);
    assert(helperToolName  != NULL);
    
    // Get the bundle identifier as a UTF-8 C string.  Also, get paths for both of 
    // the tools.
    
    retval = noErr;
    success = CFStringGetFileSystemRepresentation(bundleID, bundleIDC, sizeof(bundleIDC));
    if ( ! success ) {
        retval = coreFoundationUnknownErr;
    }
    if (retval == noErr) {
        retval = GetToolPath(bundleID, installToolName, installToolPath, sizeof(installToolPath));
    }
    if (retval == noErr) {
        retval = GetToolPath(bundleID, helperToolName,  helperToolPath,  sizeof(helperToolPath));
    }
    
    // Depending on the failure code, either run the enable command or the install 
    // from scratch command.
    
    if (retval == noErr) {
        if (failCode == kBASFailDisabled) {
            retval = RunInstallToolAsRoot(auth, installToolPath, kBASInstallToolEnableCommand, bundleIDC, NULL);
        } else {
            retval = BASInstall(auth, bundleIDC, installToolPath, helperToolPath);
        }
    }

    return retval;
}
