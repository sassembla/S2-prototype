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
 
 テストの前提として、
 SublimeText + SublimeSocket 0.10.0以降
 build.gradleがあるフォルダと同じ or 下のファイルを開いている
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
#define TEST_S2KEY_IDENTITY_6   (@"TEST_S2KEY_IDENTITY_6")
#define TEST_S2KEY_IDENTITY_7   (@"TEST_S2KEY_IDENTITY_7")

#define TEST_OUTPUT (@"./s2.log")

#define TEST_RESOURCE_PATH   (@"./testResources/")

#define TEST_SOCKETROUNDABOUT_0_LAUNCH  (@"S2Test_0_launch.sr")
#define TEST_SOCKETROUNDABOUT_1_IGNITE    (@"S2Test_1_ignite.sr")
#define TEST_SOCKETROUNDABOUT_2_ENTRY     (@"S2Test_2_entry.sr")
#define TEST_SOCKETROUNDABOUT_3_PULLING     (@"S2Test_3_pulling.sr")
#define TEST_SOCKETROUNDABOUT_4_COMPILE_READY (@"S2Test_4_compile_ready.sr")
#define TEST_SOCKETROUNDABOUT_5_COMPILE_START   (@"S2Test_5_compile_start.sr")
#define TEST_SOCKETROUNDABOUT_6_PULL_BEFORE_COMPILE (@"S2Test_6_pull_before_compile.sr")
#define TEST_SOCKETROUNDABOUT_7_COMPILECHECK    (@"S2Test_7_compile_check.sr")

#define TEST_GLOBAL_SR_PATH     (@"/Users/mondogrosso/Desktop/S2/S2/testResources/SocketRoundabout")
#define TEST_GLOBAL_NNOTIF      (@"/Users/mondogrosso/Desktop/S2/S2/testResources/nnotif")

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
    
    STAssertTrue([m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_EXITED]], @"not contained, %@", m_flags);
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
    int n = [messenger execFrom:S2_MASTER viaNotification:notif];
    [m_flags addObject:[NSNumber numberWithInt:n]];
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
    
    STAssertTrue([m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_LAUNCHED]], @"not contained");
}

/**
 着火までのチェック
 */
- (void) testIgnite {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_1}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_1_IGNITE];
    
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_IGNITED]]) {
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
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_USER_ENTRIED]]) {
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
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_UPDATED]]) {
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
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_PULLED_ALL]]) {
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
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_PULLED_ALL]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //SRへと、ダミーのコンパイルシグナルを出す
    [self sendNotification:@"DUMMY_NOTIF" withMessage:KEY_COMPILE_DUMMY withKey:@""];
    
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_COMPILE_READY]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //updateシグナルの受け取り完了
    [currentTask terminate];
}

/**
 コンパイルに入る段階で道のコードが発見された場合は、pullが発生するはず
 */
- (void) testPullUnknownSourceWhenCompile {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_6}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_6_PULL_BEFORE_COMPILE];
    
    //pulled_overがあったらOK
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_PULLED_ALL]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //このへんで新規コードを足し、updateしないまま、SRへと、ダミーのコンパイルシグナルを出す
    NSTask * generateNewFile = [[NSTask alloc] init];
    [generateNewFile setLaunchPath:@"/bin/cp"];
    [generateNewFile setArguments:@[@"/Users/mondogrosso/Desktop/S2/addTest.scala", @"/Users/mondogrosso/Desktop/S2/S2Target/"]];
    [generateNewFile launch];
    [generateNewFile waitUntilExit];
    
    [self sendNotification:@"DUMMY_NOTIF" withMessage:KEY_COMPILE_DUMMY withKey:@""];
    
    //コンパイルに至る前に、そのpull発生のため遅延する旨のサインが流れる
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_COMPILE_POSTPONED_BY_PULL]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //いらなくなった対象ファイルを消す
    NSTask * deleteFile = [[NSTask alloc] init];
    [deleteFile setLaunchPath:@"/bin/rm"];
    [deleteFile setArguments:@[@"/Users/mondogrosso/Desktop/S2/S2Target/addTest.scala"]];
    [deleteFile launch];
    [deleteFile waitUntilExit];

    [currentTask terminate];
}

/**
 コンパイルタイミングでの、ファイルの存在状態チェック
 最新のコードがある筈
 */
- (void) testPullLatestSourceWhenCompile {
    appDel = [[AppDelegate alloc]initWithArgs:@{KEY_PARENT:[messenger myNameAndMID], KEY_OUTPUT:TEST_OUTPUT, KEY_IDENTITY:TEST_S2KEY_IDENTITY_7}];
    
    NSTask * currentTask = [self controlSR:TEST_SOCKETROUNDABOUT_7_COMPILECHECK];
    
    //pulled_overがあったらOK
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_PULLED_ALL]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //HelloWorldコードを上書きする
    NSTask * generateNewFile = [[NSTask alloc] init];
    [generateNewFile setLaunchPath:@"/bin/cp"];
    [generateNewFile setArguments:@[@"/Users/mondogrosso/Desktop/S2/HelloWorld.scala2", @"/Users/mondogrosso/Desktop/S2/S2target/src/main/scala/HelloWorld.scala"]];
    [generateNewFile launch];
    [generateNewFile waitUntilExit];
    
    //S2にupdateを引き出させる
    [appDel pullClientCode:@"/Users/mondogrosso/Desktop/S2/S2target/src/main/scala/HelloWorld.scala"];
    
    
    [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    
    
    //コンパイル
    [self sendNotification:@"DUMMY_NOTIF" withMessage:KEY_COMPILE_DUMMY withKey:@""];
    
    //コンパイルが開始される
    while (![m_flags containsObject:[NSNumber numberWithInt:S2_EXEC_COMPILE_START]]) {
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    //コンパイルのために吐き出された、コンパイルされる予定のファイルも最新になっているはず
    NSString * cached = [appDel cachedFile:@"/Users/mondogrosso/Desktop/S2/S2target/src/main/scala/HelloWorld.scala"];
    NSLog(@"cached %@", cached);
    STAssertTrue([cached hasPrefix:@"object HelloWorld2"], @"not match, %@", cached);
    
    //対象ファイルを元に戻す
    NSTask * revertFile = [[NSTask alloc] init];
    [revertFile setLaunchPath:@"/bin/cp"];
    [revertFile setArguments:@[@"/Users/mondogrosso/Desktop/S2/HelloWorld.scala_original", @"/Users/mondogrosso/Desktop/S2/S2target/src/main/scala/HelloWorld.scala"]];
    [revertFile launch];
    [revertFile waitUntilExit];
    
    [currentTask terminate];
}

@end
