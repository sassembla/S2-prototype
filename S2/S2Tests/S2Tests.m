//
//  S2Tests.h
//  S2Tests
//
//  Created by sassembla on 2013/05/21.
//  Copyright (c) 2013年 KISSAKI Inc,. All rights reserved.
//

/**
 Jenkinsからの実行を維持したいので、nnotifdの代替になるイメージ。
 nnotifdの特化版。
 */
#import <SenTestingKit/SenTestingKit.h>

#import "KSMessenger.h"
#import "AppDelegate.h"

#define TEST_MASTER (@"TEST_MASTER")
#define TEST_S2KEY_IDENTITY_0   (@"TEST_S2KEY_IDENTITY_0")
#define TEST_S2KEY_IDENTITY_1   (@"TEST_S2KEY_IDENTITY_1")
#define TEST_S2KEY_IDENTITY_2   (@"TEST_S2KEY_IDENTITY_2")
#define TEST_S2KEY_IDENTITY_3   (@"TEST_S2KEY_IDENTITY_3")
#define TEST_S2KEY_IDENTITY_4   (@"TEST_S2KEY_IDENTITY_4")
#define TEST_S2KEY_IDENTITY_5   (@"TEST_S2KEY_IDENTITY_5")

#define TEST_OUTPUT (@"./s2.log")

#define TEST_RESOURCE_PATH   (@"./testResources/")

#define TEST_SOCKETROUNDABOUT_0_LAUNCH  (@"S2Test_0_launch.sr")
#define TEST_SOCKETROUNDABOUT_1_IGNITE    (@"S2Test_1_ignite.sr")
#define TEST_SOCKETROUNDABOUT_2_ENTRY     (@"S2Test_2_entry.sr")
#define TEST_SOCKETROUNDABOUT_3_PULLING     (@"S2Test_3_pulling.sr")
#define TEST_SOCKETROUNDABOUT_4_COMPILE_READY (@"S2Test_4_compile_ready.sr")
#define TEST_SOCKETROUNDABOUT_5_COMPILE_START   (@"S2Test_5_compile_start.sr")

#define TEST_GLOBAL_SR_PATH     (@"/Users/mondogrosso/Desktop/S2/S2/testResources/SocketRoundabout")
#define TEST_GLOBAL_NNOTIF      (@"/Users/mondogrosso/Desktop/S2/S2/testResources/nnotif")

#define TEST_FLAG_S2_LAUNCHED   (@"TEST_FLAG_S2_LAUNCHED")
#define TEST_FLAG_S2_IGNITED    (@"TEST_FLAG_S2_IGNITED")
#define TEST_FLAG_S2_USER_ENTRIED   (@"TEST_FLAG_S2_USER_ENTRIED")
#define TEST_FLAG_S2_PULLING    (@"TEST_FLAG_S2_PULLING")
#define TEST_FLAG_S2_UPDATED    (@"TEST_FLAG_S2_UPDATED")
#define TEST_FLAG_S2_PULLED_ALL (@"TEST_FLAG_S2_PULLED_ALL")
#define TEST_FLAG_S2_COMPILE_READY  (@"TEST_FLAG_S2_COMPILE_READY")
#define TEST_FLAG_S2_COMPILE_START  (@"TEST_FLAG_S2_COMPILE_START")
#define TEST_FLAG_S2_EXITED     (@"TEST_FLAG_S2_EXITED")
@interface S2Tests : SenTestCase

@end

@implementation S2Tests {
    KSMessenger * messenger;
    AppDelegate * appDel;
    
    NSMutableArray * m_flags;
}

- (void)setUp {
    [super setUp];
    messenger = [[KSMessenger alloc]initWithBodyID:self withSelector:@selector(receiver:) withName:TEST_MASTER];
    m_flags = [[NSMutableArray alloc]init];
}

- (void)tearDown {
    [appDel close];
    
    STAssertTrue([m_flags containsObject:TEST_FLAG_S2_EXITED], @"not contained, %@", m_flags);
    [m_flags removeAllObjects];
    

    [messenger closeConnection];
    [super tearDown];
}

/**
 .srファイルの起動を行う
 */
- (NSTask * ) controlSR:(NSString * )loadSRSettingFilePath {
    NSString * testSRResourcePath = [[NSString alloc]initWithFormat:@"%@%@", TEST_RESOURCE_PATH, loadSRSettingFilePath];
    NSArray * execArray = @[@"-s", testSRResourcePath];
    NSTask * task = [[NSTask alloc]init];
    [task setLaunchPath:TEST_GLOBAL_SR_PATH];
    [task setArguments:execArray];
    [task launch];
    return task;
}

- (void) receiver:(NSNotification * )notif {
    NSDictionary * dict = [messenger tagValueDictionaryFromNotification:notif];
    
    switch ([messenger execFrom:S2_MASTER viaNotification:notif]) {
        case S2_EXEC_LAUNCHED:{
            [m_flags addObject:TEST_FLAG_S2_LAUNCHED];
            break;
        }
        case S2_EXEC_IGNITED:{
            [m_flags addObject:TEST_FLAG_S2_IGNITED];
            break;
        }
        case S2_EXEC_USER_ENTRIED:{
            [m_flags addObject:TEST_FLAG_S2_USER_ENTRIED];
            break;
        }
        case S2_EXEC_PULLING:{
            [m_flags addObject:TEST_FLAG_S2_PULLING];
            break;
        }
        case S2_EXEC_UPDATED:{
            [m_flags addObject:TEST_FLAG_S2_UPDATED];
            break;
        }
        case S2_EXEC_PULLED_ALL:{
            [m_flags addObject:TEST_FLAG_S2_PULLED_ALL];
            break;
        }
        case S2_EXEC_COMPILE_READY:{
            [m_flags addObject:TEST_FLAG_S2_COMPILE_READY];
            break;
        }
        case S2_EXEC_COMPILE_START:{
            [m_flags addObject:TEST_FLAG_S2_COMPILE_START];
            break;
        }
        case S2_EXEC_EXITED:{
            [m_flags addObject:TEST_FLAG_S2_EXITED];
            break;
        }
        default:
            break;
    }
}

- (void) sendNotification:(NSString * )identity withMessage:(NSString * )message withKey:(NSString * )key {
    
    NSArray * clArray = @[@"-t", identity, @"-i", message, @"-o", @"./test.log"];
    NSLog(@"clArray %@", clArray);
    NSTask * task1 = [[NSTask alloc] init];
    [task1 setLaunchPath:TEST_GLOBAL_NNOTIF];
    [task1 setArguments:clArray];
    [task1 launch];
    [task1 waitUntilExit];
}


/**
 Launchまでのチェック
 */
- (void) testLaunch {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_0}];
    
    /**
     起動したタイミングで、なにが起こっていてほしいか
     ・リソースが葬ってある
     */
    
    STAssertTrue([m_flags containsObject:TEST_FLAG_S2_LAUNCHED], @"not contained");
}

/**
 着火までのチェック
 */
- (void) testIgnite {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_1}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_1_IGNITE];
    
    while (![m_flags containsObject:TEST_FLAG_S2_IGNITED]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //着火シグナルの受け取り完了
    [currentTask terminate];
}

/**
 着火後、entryを行う
 */
- (void) testEntry {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_2}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_2_ENTRY];
    
    //entryがあったらOK
    while (![m_flags containsObject:TEST_FLAG_S2_USER_ENTRIED]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }

    //entryシグナルの受け取り完了
    [currentTask terminate];
}

/**
 着火後 ソース取得までをチェック
 */
- (void) testPulling {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_3}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_3_PULLING];
    
    //updateが一つでもあったらOK
    while (![m_flags containsObject:TEST_FLAG_S2_UPDATED]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //updateシグナルの受け取り完了
    [currentTask terminate];
}


/**
 予定されているpullが終わったタイミングでのupdate完了=pulledAllな動作をチェックする
 */
- (void) testPullingOver {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_4}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_4_COMPILE_READY];
    
    //pulled_overがあったらOK
    while (![m_flags containsObject:TEST_FLAG_S2_PULLED_ALL]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //updateシグナルの受け取り完了
    [currentTask terminate];
}

/**
 pull完了からコンパイル開始まで
 */
- (void) testPullingOverThenStartFirstCompilation {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_5}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_5_COMPILE_START];
    
    //pulled_overがあったらOK
    while (![m_flags containsObject:TEST_FLAG_S2_PULLED_ALL]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //SRへと、ダミーのコンパイルシグナルを出す
    [self sendNotification:@"DUMMY_NOTIF" withMessage:KEY_COMPILE_DUMMY withKey:@""];
    
    while (![m_flags containsObject:TEST_FLAG_S2_COMPILE_READY]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //updateシグナルの受け取り完了
    [currentTask terminate];
}

/**
 動作中のS2停止
 */
//- (void) testExit {
////    while (![m_flags containsObject:TEST_FLAG_S2_IGNITED]) {
////        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
////    }
//
////    [self run];
//}

/**
 起動後の再起動
 */
//- (void) testReset {
//    
//}



//
//- (void) testCompile {
//    STFail(@"Unit tests are not implemented yet in S2Tests");
//}
//
//- (void) testUpdate {
//    
//}


@end
