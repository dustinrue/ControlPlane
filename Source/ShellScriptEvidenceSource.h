//
//  ShellScriptEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 11/5/2011.
//
// This evidence source allows the end user to create
// their own custom evidence source using an external program,
// or script.  Anything can be used so long as it returns 0
// for success and 1 for failure.

#import "EvidenceSource.h"

/*!
 @class ShellScriptEvidenceSource
 This evidence source allows the end user to create
 their own custom evidence source using an external program,
 or script.  Anything can be used so long as it returns 0
 for false and 1 for true.
 @updated 11-06-2011
*/

@interface ShellScriptEvidenceSource : EvidenceSource {
    
    NSString *currentFileName;
    NSString *scriptInterval;
    NSArray *myTasks;
    NSTimer *ruleUpdateTimer;
    
    // used to store timer objects for the spawned tasks
    NSMutableDictionary *taskTimers;
    
    // used to store script results
    NSMutableDictionary *scriptResults;

}



/*!
 @function init;
 @abstract Initializes a new ShellScriptEvidenceSource object
 @result Returns an initialized ShellScriptEvidenceSource object
 */
- (id)init;


/*!
 @function dealloc
 @abstract Destroys the ShellScriptEvidenceSource object
 */
- (void)dealloc;


/*!
 @function start
 @abstract Starts the evidence source
 */
- (void)start;


/*!
 @function start
 @abstract Stops the evidence source
 */
- (void)stop;


/*!
 @function name
 @abstract Returns the name of the evidence source
 @result NSString object with the value "ShellScriptEvidenceSource"
 */
- (NSString *)name;


/*!
 @function doesRuleMatch
 @abstract Returns true/false if the passed rule matches
 @param rule The rule to be matched
 */
- (BOOL)doesRuleMatch:(NSDictionary *)rule;


/*!
 @function readFromPanel
 @abstract reads values from the custom panel
 @return Returns a NSMutableDictionary of values from the panel, these should be stored
 */
- (NSMutableDictionary *)readFromPanel;


/*!
 @function writeToPanel:usingType:
 @abstract Writes values to a restored panel
 */
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (void)getRuleList;
- (void)clearCollectedData;

/*!
 @function browseForScript
 */

- (IBAction)browseForScript:(id)sender;


@property (assign) IBOutlet NSString *currentFileName;
@property (assign) IBOutlet NSString *scriptInterval;




@end
