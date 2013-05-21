//
//  AppDelegate.h
//  S2
//
//  Created by sassembla on 2013/05/21.
//  Copyright (c) 2013年 KISSAKI Inc,. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 NSDistNotifを受け取って、Scalaのコンパイルを行う
 */

#define KEY_PERFIX  (@"-")


typedef enum {
    STATUS_STOPPED= 0,
    STATUS_RUNNING
} S2_status;


#define VERSION (@"0.0.1")

#define KEY_VERSION     (@"-v")


#define KEY_IDENTITY    (@"-i")
#define KEY_CONTROL     (@"-c")
#define KEY_OUTPUT      (@"-o")
#define KEY_KILL        (@"-kill")
#define KEY_NOTIFID     (@"--nid")
#define KEY_EXECUTE     (@"-e")

#define CODE_START  (@"start")
#define CODE_STOP   (@"stop")


#define DEBUG_BOOTFROMAPP   (@"DEBUG_BOOTFROMAPP")

#define PRIVATEKEY_SERVERS     (@"servers")

#define DEFAULT_OUTPUT_PATH (@"DEFAULT_OUTPUT_PATH")


#define MESSAGE_LAUNCHED    (@"S2 launched")
#define MESSAGE_EXECUTE_IGNOREDONLAUNCH (@"S2 ignored executes on laundh")
#define MESSAGE_EXECUTE_IGNOREDBEFORESTART  (@"S2 ignored executes before server start")
#define MESSAGE_PREEXECUTE      (@"S2 will execute:")
#define MESSAGE_EXECUTE_FAILED  (@"S2 failed to execute:")
#define MESSAGE_EXECUTE_LAUNCHED    (@"S2 executes was launched:")
#define MESSAGE_RECEIVED            (@"S2 received:")
#define MESSAGE_MESSAGEID_RECEIVED  (@"S2 received notification id:")
#define MESSAGE_INPUTRECEIVED (@"S2 input received")
#define MESSAGE_UPDATED     (@"S2 updated")
#define MESSAGE_SERVING     (@"S2 start serving")
#define MESSAGE_STOPSERVING (@"S2 stop serving")
#define MESSAGE_TEARDOWN    (@"S2 teardown")

//execute
#define S2_HEADER   (@"S2@")
#define S2_JSON_PARTITION   (@"S2:")
#define S2_SPACE    (@" ")
#define S2_DEFAULT_ROUTE    (@"S2_DEFAULT_ROUTE")

#define DEFINE_PIPE (@"|")

#define FAILBY_NOEXEC   (@"there is no executable command before '|'")
#define FAILBY_NOSPACEWHILEPIPE   (@"there is no space before '|'. should be separate '|' in -e param")


@interface AppDelegate : NSObject <NSApplicationDelegate>

- (id) initWithArgs:(NSDictionary * )dict;

- (bool) isRunning;

- (NSString * )identity;

- (void) writeLogLine:(NSString * )message;
- (NSArray * )bufferedOutput;
- (NSArray * )runningTasks;
- (NSString * )outputPath;

@end
