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

#define S2_MASTER   (@"S2_MASTER")

typedef enum {
    S2_EXEC_LAUNCHED,
    S2_EXEC_IGNITED,
    S2_EXEC_USER_ENTRIED,
    S2_EXEC_PULLING,
    S2_EXEC_UPDATED,
    S2_EXEC_PULLED_ALL,
    S2_EXEC_COMPILE_INFOREQUST,
    S2_EXEC_COMPILE_READY,
    S2_EXEC_COMPILE_CANCELLED,
    S2_EXEC_COMPILE_START,
    S2_EXEC_EXITED
} S2_EXECS;


typedef enum {
    STATUS_STOPPED= 0,
    STATUS_RUNNING
} S2_status;


#define VERSION (@"0.0.1")

#define KEY_VERSION     (@"-v")
#define KEY_PARENT      (@"-parent")


#define KEY_IDENTITY    (@"-i")
#define KEY_OUTPUT      (@"-o")
#define KEY_KILL        (@"-kill")

//routing
#define KEY_IGNITE      (@"-ignite")
#define KEY_ENTRY       (@"-entry")
#define KEY_UPDATE      (@"-update")
#define KEY_COMPILE     (@"-compile")
#define KEY_COMPILE_DUMMY   (@"S2-compile")
#define KEY_RESTART     (@"-restart")


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

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (id) initWithArgs:(NSDictionary * )dict;
- (void) writeLogLine:(NSString * )message;

- (void) close;
@end
