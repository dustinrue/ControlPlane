/*
  JNI LmuTracker - JNI Ambient Light Sensor detection for Apple MacBookPro.
  
  (c) copyright 2008 Martin Raedlinger (www.formatlos.de)
  based on Amit Singh experiments with the Ambient Light Sensor
  
  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General
  Public License along with this library; if not, write to the
  Free Software Foundation, Inc., 59 Temple Place, Suite 330,
  Boston, MA  02111-1307  USA
 */
 
 
#include "lmu_LmuTracker.h"
#include "LmuTrackerCommon.h"

#include <jni.h>
#include <IOKit/IOKitLib.h> 
#include <CoreFoundation/CoreFoundation.h> 
#include <string.h>
#include <stdint.h>

static io_connect_t dataPort = 0;
static int last_left = 0;
static int last_right = 0;

/**
* function reads the data from the ambient light sensor 
*/
void read_lmu(int *l, int *r)
{
	kern_return_t kr;  
	uint32_t outputCnt = 2;
	uint64_t    scalarI_64[2];
	scalarI_64[0] = 0;
	scalarI_64[1] = 0;
	
	
	// Check if Mac OS X 10.5 API is available..
	if (IOConnectCallScalarMethod != NULL) 
		kr = IOConnectCallScalarMethod(dataPort, kGetSensorReadingID, NULL, 0, scalarI_64, &outputCnt); 
	 
	if (kr == KERN_SUCCESS) 
	{  
		last_left = scalarI_64[0];
		last_right = scalarI_64[1];
		*l = last_left;
		*r = last_right;
		return;  
	}  
	if (kr == kIOReturnBusy)  
	{
		*l = last_left;
		*r = last_right;
		return;
	}
	
	// Error
	mach_error("I/O Kit error:", kr);  
	exit(kr); 
}


// JNI Function to return an array of ints w/ sensor values
JNIEXPORT jintArray JNICALL Java_lmu_LmuTracker_readLMU (JNIEnv *env, jclass this) 
{

	kern_return_t kr;  
	io_service_t serviceObject; 
	int l,r;
	l = r = 0;   
	
	// Look up a registered IOService object whose class is AppleLMUController  
	serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault,  IOServiceMatching("AppleLMUController"));  
	
	if (!serviceObject) 
	{  
		fprintf(stderr, "failed to find ambient light sensor\n");  
		exit(1);  
	}  
	
	// Create a connection to the IOService object  
	kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &dataPort);  
	IOObjectRelease(serviceObject);  
	if (kr != KERN_SUCCESS) 
	{  
		mach_error("IOServiceOpen:", kr);  
		exit(kr);  
	}  
	
	read_lmu(&l,&r);
	  
	jintArray jr;
	jsize rlen = 2;
	jr = (*env)->NewIntArray(env, rlen);
	int size = 2;
	long *data;
	data = (long *)malloc(sizeof(long)*size);
	data[0] = l; data[1] = r;
	(*env)->SetIntArrayRegion(env,jr, 0, size,data);
	free(data);
	return jr;
}