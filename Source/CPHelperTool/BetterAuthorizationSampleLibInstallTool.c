/*
	File:       BetterAuthorizationSampleLibInstallTool.c

    Contains:   Tool to install BetterAuthorizationSampleLib-based privileged helper tools.

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

#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <sys/stat.h>

// Allows access to path information associated with tool and plist installation
// from BetterAuthorizationSampleLib.h
#define BAS_PRIVATE 1		

#include "BetterAuthorizationSampleLib.h"

extern char **environ;

static int RunLaunchCtl(
	bool						junkStdIO, 
	const char					*command, 
	const char					*plistPath
)
	// Handles all the invocations of launchctl by doing the fork() + execve()
	// for proper clean-up. Only two commands are really supported by our
	// implementation; loading and unloading of a job via the plist pointed at 
	// (const char *) plistPath.
{	
	int				err;
	const char *	args[5];
	pid_t			childPID;
	pid_t			waitResult;
	int				status;
	
	// Pre-conditions.
	assert(command != NULL);
	assert(plistPath != NULL);
	
    // Make sure we get sensible logging even if we never get to the waitpid.
    
    status = 0;
    
    // Set up the launchctl arguments.  We run launchctl using StartupItemContext 
	// because, in future system software, launchctl may decide on the launchd 
	// to talk to based on your Mach bootstrap namespace rather than your RUID.
    
	args[0] = "/bin/launchctl";
	args[1] = command;				// "load" or "unload"
	args[2] = "-w";
	args[3] = plistPath;			// path to plist
	args[4] = NULL;

    fprintf(stderr, "launchctl %s %s '%s'\n", args[1], args[2], args[3]);
	
    // Do the standard fork/exec dance.
    
	childPID = fork();
	switch (childPID) {
		case 0:
			// child
			err = 0;
            
            // If we've been told to junk the I/O for launchctl, open 
            // /dev/null and dup that down to stdin, stdout, and stderr.
            
			if (junkStdIO) {
				int		fd;
				int		err2;

				fd = open("/dev/null", O_RDWR);
				if (fd < 0) {
					err = errno;
				}
				if (err == 0) {
					if ( dup2(fd, STDIN_FILENO) < 0 ) {
						err = errno;
					}
				}
				if (err == 0) {
					if ( dup2(fd, STDOUT_FILENO) < 0 ) {
						err = errno;
					}
				}
				if (err == 0) {
					if ( dup2(fd, STDERR_FILENO) < 0 ) {
						err = errno;
					}
				}
				err2 = close(fd);
				if (err2 < 0) {
					err2 = 0;
				}
				if (err == 0) {
					err = err2;
				}
			}
			if (err == 0) {
				err = execve(args[0], (char **) args, environ);
			}
			if (err < 0) {
				err = errno;
			}
			_exit(EXIT_FAILURE);
			break;
		case -1:
			err = errno;
			break;
		default:
			err = 0;
			break;
	}
	
    // Only the parent gets here.  Wait for the child to complete and get its 
    // exit status.
	
	if (err == 0) {
		do {
			waitResult = waitpid(childPID, &status, 0);
		} while ( (waitResult == -1) && (errno == EINTR) );

		if (waitResult < 0) {
			err = errno;
		} else {
			assert(waitResult == childPID);

            if ( ! WIFEXITED(status) || (WEXITSTATUS(status) != 0) ) {
                err = EINVAL;
            }
		}
	}

    fprintf(stderr, "launchctl -> %d %ld 0x%x\n", err, (long) childPID, status);
	
	return err;
}

static int CopyFileOverwriting(
	const char					*sourcePath, 
	mode_t						destMode, 
	const char					*destPath
)
	// Our own version of a file copy. This routine will either handle
	// the copy of the tool binary or the plist file associated with
	// that binary. As the function name suggests, it writes over any 
	// existing file pointed to by (const char *) destPath.
{
	int			err;
	int			junk;
	int			sourceFD;
	int			destFD;
	char		buf[65536];
	
	// Pre-conditions.
	assert(sourcePath != NULL);
	assert(destPath != NULL);
	
    (void) unlink(destPath);
	
	destFD = -1;
	
	err = 0;
	sourceFD = open(sourcePath, O_RDONLY);
	if (sourceFD < 0) {
		err = errno;
	}
	
	if (err == 0) {
		destFD = open(destPath, O_CREAT | O_EXCL | O_WRONLY, destMode);
		if (destFD < 0) {
			err = errno;
		}
	}
	
	if (err == 0) {
		ssize_t	bytesReadThisTime;
		ssize_t	bytesWrittenThisTime;
		ssize_t	bytesWritten;
		
		do {
			bytesReadThisTime = read(sourceFD, buf, sizeof(buf));
			if (bytesReadThisTime < 0) {
				err = errno;
			}
			
			bytesWritten = 0;
			while ( (err == 0) && (bytesWritten < bytesReadThisTime) ) {
				bytesWrittenThisTime = write(destFD, &buf[bytesWritten], bytesReadThisTime - bytesWritten);
				if (bytesWrittenThisTime < 0) {
					err = errno;
				} else {
					bytesWritten += bytesWrittenThisTime;
				}
			}

		} while ( (err == 0) && (bytesReadThisTime != 0) );
	}
	
	// Clean up.
	
	if (sourceFD != -1) {
		junk = close(sourceFD);
		assert(junk == 0);
	}
	if (destFD != -1) {
		junk = close(destFD);
		assert(junk == 0);
	}

    fprintf(stderr, "copy '%s' %#o '%s' -> %d\n", sourcePath, (int) destMode, destPath, err);
	
	return err;
}

static int InstallCommand(
	const char *				bundleID, 
	const char *				toolSourcePath, 
	const char *				plistSourcePath
)
	// Heavy lifting function for handling all the necessary steps to install a
	// helper tool in the correct location, with the correct permissions,
	// and call launchctl in order to load it as a current job.
{
	int			err;
	char		toolDestPath[PATH_MAX];
	char		plistDestPath[PATH_MAX];
	struct stat	sb;
    static const mode_t kDirectoryMode  = ACCESSPERMS & ~(S_IWGRP | S_IWOTH);
    static const mode_t kExecutableMode = ACCESSPERMS & ~(S_IWGRP | S_IWOTH);
    static const mode_t kFileMode       = DEFFILEMODE & ~(S_IWGRP | S_IWOTH);
	
	// Pre-conditions.
	assert(bundleID != NULL);
	assert(toolSourcePath != NULL);
	assert(plistSourcePath != NULL);
	
	(void) snprintf(toolDestPath,  sizeof(toolDestPath),  kBASToolPathFormat,  bundleID);
	(void) snprintf(plistDestPath, sizeof(plistDestPath), kBASPlistPathFormat, bundleID);

    // Stop the helper tool if it's currently running.

	(void) RunLaunchCtl(true, "unload", plistDestPath);

    // Create the PrivilegedHelperTools directory.  The owner will be "root" because 
    // we're running as root (our EUID is 0).  The group will be "admin" because 
    // it's inherited from "/Library".  The permissions will be rwxr-xr-x because 
    // of kDirectoryMode combined with our umask.

	err = mkdir(kBASToolDirPath, kDirectoryMode);
	if (err < 0) {
		err = errno;
	}
    fprintf(stderr, "mkdir '%s' %#o -> %d\n", kBASToolDirPath, kDirectoryMode, err);
	if ( (err == 0) || (err == EEXIST) ) {
		err = stat(kBASToolDirPath, &sb);
		if (err < 0) {
			err = errno;
		}
    }
    
    // /Library/PrivilegedHelperTools may have come from a number of places:
    //
    // A. We may have just created it.  In this case it will be 
    //    root:admin rwxr-xr-x.
    //
    // B. It may have been correctly created by someone else.  By definition, 
    //    that makes it root:wheel rwxr-xr-x.
    //
    // C. It may have been created (or moved here) incorrectly (or maliciously) 
    //    by someone else.  In that case it will be u:g xxxxxxxxx, where u is 
    //    not root, or root:g xxxxwxxwx (that is, root-owned by writeable by 
    //    someone other than root).
    //
    // In case A, we want to correct the group.  In case B, we want to do 
    // nothing.  In case C, we want to fail.

    if (err == 0) {
        if ( (sb.st_uid == 0) && (sb.st_gid == 0) ) {
            // case B -- do nothing
        } else if ( (sb.st_uid == 0) && (sb.st_gid != 0) && ((sb.st_mode & ALLPERMS) == kDirectoryMode) ) {
            // case A -- fix the group ID
            // 
            // This is safe because /Library is sticky and the file is owned 
            // by root, which means that only root can move it.  Also, we 
            // don't have to worry about malicious files existing within the 
            // directory because its only writeable by root.

            err = chown(kBASToolDirPath, -1, 0);
            if (err < 0) {
                err = errno;
            }
            fprintf(stderr, "chown -1:0 '%s' -> %d\n", kBASToolDirPath, err);
        } else {
            fprintf(stderr, "bogus perms on '%s' %d:%d %o\n", kBASToolDirPath, (int) sb.st_uid, (int) sb.st_gid, (int) sb.st_mode);
            err = EPERM;
        }
	}

    // Then create the known good copy.  The ownership and permissions 
    // will be set appropriately, as described in the comments for mkdir. 
    // We don't have to worry about atomicity because this tool won't be 
    // looked at until our plist is installed.

	if (err == 0) {
		err = CopyFileOverwriting(toolSourcePath, kExecutableMode, toolDestPath);
	}

    // For the plist, our caller has created the file in /tmp and we just copy it 
    // into the correct location.  This ensures that the file is complete 
    // and valid before anyone starts looking at it and will also overwrite 
	// any existing file with this new version.
    // 
	// Since we have to read/write in the file byte by byte to make sure that 
	// the file is complete we are rolling our own 'copy'. This clearly is 
	// ignoring atomicity since we do not roll back to the state of 'what was 
	// previously there' if there is an error; rather, whatever has been 
	// written up to that point of granular failure /is/ the state of the 
	// plist file.

	if (err == 0) {
		err = CopyFileOverwriting(plistSourcePath, kFileMode, plistDestPath);
	}
	
    // Use launchctl to load our job.  The plist file starts out disabled, 
    // so we pass "-w" to enable it permanently.

	if (err == 0) {
		err = RunLaunchCtl(false, "load", plistDestPath);
	}
	
	return err;
}

static int EnableCommand(
	const char					*bundleID
)
	// Utility function to call through to RunLaunchCtl in order to load a job
	// given by the path contructed from the (const char *) bundleID.
{
	int		err;
	char	plistPath[PATH_MAX];
	
	// Pre-condition.
	assert(bundleID != NULL);
	
	(void) snprintf(plistPath, sizeof(plistPath), kBASPlistPathFormat, bundleID);
	err = RunLaunchCtl(false, "load", plistPath);

	return err;
}

int main(int argc, char **argv)
{
	int err;
	
	// Print our PID so that the app can avoid creating zombies.

	fprintf(stdout, kBASAntiZombiePIDToken1 "%ld" kBASAntiZombiePIDToken2 "\n", (long) getpid());
	fflush(stdout);

    // On the client side, AEWP only gives a handle to stdout, so we dup stdout 
    // downto stderr for the rest of this tool.  This ensures that all our output 
	// makes it to the client.

	err = dup2(STDOUT_FILENO, STDERR_FILENO);
	if (err < 0) {
		err = errno;
	} else {
		err = 0;
	}

    // Set up the standard umask.  The goal here is to be robust in the 
	// face of common environmental changes, not to resist a malicious attack.
	// Also sync the RUID to the 0 because launchctl keys off the RUID (at least 
	// on 10.4.x).

	if (err == 0) {
		(void) umask(S_IWGRP | S_IWOTH);
		
        err = setuid(0);
        if (err < 0) {
            fprintf(stderr, "setuid\n");
            err = EINVAL;
        }
	}
	
	if ( (err == 0) && (argc < 2) ) {
		fprintf(stderr, "usage\n");
		err = EINVAL;
	}

	// The first argument is the command.  Switch off that and extract the 
	// remaining arguments and pass them to our command routines.
	
	if (err == 0) {
		if ( strcmp(argv[1], kBASInstallToolInstallCommand) == 0 ) {
			if (argc == 5) {
				err = InstallCommand(argv[2], argv[3], argv[4]);
			} else {
				fprintf(stderr, "usage3\n");
				err = EINVAL;
			}
		} else if ( strcmp(argv[1], kBASInstallToolEnableCommand) == 0 ) {
			if (argc == 3) {
				err = EnableCommand(argv[2]);
			} else {
				fprintf(stderr, "usage4\n");
				err = EINVAL;
			}
		} else {
			fprintf(stderr, "usage2\n");
			err = EINVAL;
		}
	}

	// Write "oK" to stdout and quit.  The presence of the "oK" on the last 
	// line of output is used by the calling code to detect success.
	
	if (err == 0) {
		fprintf(stderr, kBASInstallToolSuccess "\n");
    } else {
		fprintf(stderr, kBASInstallToolFailure "\n", err);
	}
	
	return (err == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
