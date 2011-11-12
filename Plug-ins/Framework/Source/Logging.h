//
//  Logging.h
//  ControlPlane
//
//  Created by David Jennes on 11/11/11.
//  Copyright 2011. All rights reserved.
//

#import <NSLogger/LoggerClient.h>

// Log levels

#define ERROR	0
#define WARN	1
#define INFO	2
#define VERBOSE	3

// Log components

#define ACTION		@"action"
#define CONTEXT		@"context"
#define PLUGIN		@"plugin"
#define PREFERENCES	@"preferences"
#define RULE		@"rule"
#define SOURCE		@"source"
#define VIEW		@"view"

// Enable or disable DLogs depending on logging level

#ifndef LOG_LEVEL
	#define LOG_LEVEL WARN
#endif

#define ACTUAL_LOG(tag, level, ...)	LogMessageF(__FILE__, __LINE__, __FUNCTION__, tag, level, __VA_ARGS__)
#define NOTHING_LOG					do { } while (0)

#if LOG_LEVEL < ERROR
	#define LogError(...)			NOTHING_LOG
#else
	#define LogError(tag, ...)		ACTUAL_LOG(tag, ERROR, __VA_ARGS__)
#endif
#if LOG_LEVEL < WARN
	#define LogWarn(...)			NOTHING_LOG
#else
	#define LogWarn(tag, ...)		ACTUAL_LOG(tag, WARN, __VA_ARGS__)
#endif
#if LOG_LEVEL < INFO
	#define LogInfo(...)			NOTHING_LOG
#else
	#define LogInfo(tag, ...)		ACTUAL_LOG(tag, INFO, __VA_ARGS__)
#endif
#if LOG_LEVEL < VERBOSE
	#define LogVerbose(...)			NOTHING_LOG
#else
	#define LogVerbose(tag, ...)	ACTUAL_LOG(tag, VERBOSE, __VA_ARGS__)
#endif

// Component logs

#define LogError_Action(...)		LogError(ACTION, __VA_ARGS__)
#define LogWarn_Action(...)			LogWarn(ACTION, __VA_ARGS__)
#define LogInfo_Action(...)			LogInfo(ACTION, __VA_ARGS__)
#define LogVerbose_Action(...)		LogVerbose(ACTION, __VA_ARGS__)
#define LogError_Context(...)		LogError(CONTEXT, __VA_ARGS__)
#define LogWarn_Context(...)		LogWarn(CONTEXT, __VA_ARGS__)
#define LogInfo_Context(...)		LogInfo(CONTEXT, __VA_ARGS__)
#define LogVerbose_Context(...)		LogVerbose(CONTEXT, __VA_ARGS__)
#define LogError_Plugin(...)		LogError(PLUGIN, __VA_ARGS__)
#define LogWarn_Plugin(...)			LogWarn(PLUGIN, __VA_ARGS__)
#define LogInfo_Plugin(...)			LogInfo(PLUGIN, __VA_ARGS__)
#define LogVerbose_Plugin(...)		LogVerbose(PLUGIN, __VA_ARGS__)
#define LogError_Preferences(...)	LogError(PREFERENCES, __VA_ARGS__)
#define LogWarn_Preferences(...)	LogWarn(PREFERENCES, __VA_ARGS__)
#define LogInfo_Preferences(...)	LogInfo(PREFERENCES, __VA_ARGS__)
#define LogVerbose_Preferences(...)	LogVerbose(PREFERENCES, __VA_ARGS__)
#define LogError_Rule(...)			LogError(RULE, __VA_ARGS__)
#define LogWarn_Rule(...)			LogWarn(RULE, __VA_ARGS__)
#define LogInfo_Rule(...)			LogInfo(RULE, __VA_ARGS__)
#define LogVerbose_Rule(...)		LogVerbose(RULE, __VA_ARGS__)
#define LogError_Source(...)		LogError(SOURCE, __VA_ARGS__)
#define LogWarn_Source(...)			LogWarn(SOURCE, __VA_ARGS__)
#define LogInfo_Source(...)			LogInfo(SOURCE, __VA_ARGS__)
#define LogVerbose_Source(...)		LogVerbose(SOURCE, __VA_ARGS__)
#define LogError_View(...)			LogError(VIEW, __VA_ARGS__)
#define LogWarn_View(...)			LogWarn(VIEW, __VA_ARGS__)
#define LogInfo_View(...)			LogInfo(VIEW, __VA_ARGS__)
#define LogVerbose_View(...)		LogVerbose(VIEW, __VA_ARGS__)
