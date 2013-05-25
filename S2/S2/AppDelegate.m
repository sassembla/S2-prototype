//
//  AppDelegate.m
//  S2
//
//  Created by sassembla on 2013/05/21.
//  Copyright (c) 2013年 KISSAKI Inc,. All rights reserved.
//

#import "AppDelegate.h"
#import "KSMessenger.h"

#define S2_IDENTITY (@"S2")
#define S2_KEY      (@"S2_KEY_2013_05_24_12_10_09")

@implementation AppDelegate {
    KSMessenger * messenger;
    
    NSMutableDictionary * m_settingDict;
    
    //S2 code reoisitory
    NSMutableDictionary * m_codeDict;
    
    NSFileHandle * m_writeHandle;
    
    NSMutableArray * m_tasks;
    NSMutableArray * m_pulling;
}


/**
 起動ルート
 */
- (id) initWithArgs:(NSDictionary * )dict {
    if (dict[KEY_VERSION]) NSLog(@"nnotifd version:%@", VERSION);
    
    if (self = [super init]) {
        messenger = [[KSMessenger alloc]initWithBodyID:self withSelector:@selector(receiver:) withName:S2_MASTER];
        if (dict[KEY_PARENT]) {
            [messenger connectParent:dict[KEY_PARENT]];
        }
        
        if (dict[KEY_IDENTITY]) {
            [[NSDistributedNotificationCenter defaultCenter]addObserver:self selector:@selector(distNotifReceiver:) name:dict[KEY_IDENTITY] object:nil];
        } else [[NSDistributedNotificationCenter defaultCenter]addObserver:self selector:@selector(distNotifReceiver:) name:S2_IDENTITY object:nil];
        
        [self callParent:S2_EXEC_LAUNCHED];
        
        m_settingDict = [[NSMutableDictionary alloc]initWithDictionary:@{KEY_IDENTITY:S2_IDENTITY}];
        
        
        
        if (dict[KEY_OUTPUT]) {
            [self setOutput:dict[KEY_OUTPUT]];
            [m_settingDict setValue:dict[KEY_OUTPUT] forKey:KEY_OUTPUT];
            [self writeLogLine:MESSAGE_LAUNCHED];
        }
        
        m_codeDict = [[NSMutableDictionary alloc]init];
        
        //initialize work
        [self removeFiles];
        
        m_tasks = [[NSMutableArray alloc]init];
        m_pulling = [[NSMutableArray alloc]init];
    }
    return self;
}

- (void) distNotifReceiver:(NSNotification * )notif {
    NSDictionary * dict = [notif userInfo];
    NSLog(@"distNotifReceiver dict%@", dict);
    [self writeLogLine:[NSString stringWithFormat:@"%@%@", MESSAGE_RECEIVED, dict]];
    
    //コマンドライン動作を行う
    if (dict[S2_KEY]) {
        NSString * execs = [[NSString alloc]initWithString:dict[S2_KEY]];
        NSArray * headAndBody = [[execs componentsSeparatedByString:@" "] subarrayWithRange:NSMakeRange(0,1)];
        
        NSString * head = headAndBody[0];
        NSString * headAndSpace = [[NSString alloc]initWithFormat:@"%@ ", head];
        NSString * body;
        
        if ([head length] < [execs length]) {
            body = [execs substringFromIndex:[headAndSpace length]];
        }
        
        //ignite 引数無し
        if ([execs isEqualToString:KEY_IGNITE]) {
            [self ignite];
        }
        
        //entry -entry:paths
        if ([head isEqualToString:KEY_ENTRY]) {
            [self entry:body];
        }
        
        //update -update:path sourcecode
        if ([head hasPrefix:KEY_UPDATE]) {
            [self callParent:S2_EXEC_UPDATED];
            
            NSString * path = [head componentsSeparatedByString:@":"][1];
//            NSString * headAndSpace = [[NSString alloc]initWithFormat:@"%@%@", head, @" "];
            
            //remove header from code
//            NSRange rangeOfSubstring = [execs rangeOfString:headAndSpace];
            NSString * source = [execs substringFromIndex:([head length]+1)];
            NSLog(@"path %@", path);
            NSLog(@"source %@", source);
            
            //update code
            [m_codeDict setValue:source forKey:path];
        }
        
        
        if ([head isEqualToString:KEY_COMPILE]) {
            //すでにコンパイル中であったら即停止
            [self reset];
            
            if (body) {
                [self callParent:S2_EXEC_COMPILE_READY];
                [self compile:body];
            } else {
                NSString * compileId = [KSMessenger generateMID];
                [self callParent:S2_EXEC_COMPILE_INFOREQUST];
                NSString * entryRequestMessage = [[NSString alloc] initWithFormat:@"ss@getAllFilePath:{\"anchor\":\"build.gradle\",\"header\":\"-compile \"}->(paths|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\"}->showAtLog:{\"message\":\"entry:%@\"}->showStatusMessage:{\"message\":\"entry:%@\"}", compileId, compileId];
                
                [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":entryRequestMessage} deliverImmediately:YES];
            }
            
        }

        
        
        if ([head isEqualToString:KEY_RESTART]) {
            
            [self reset];
        }
        
        if ([head isEqualToString:KEY_KILL]) {
            [[NSDistributedNotificationCenter defaultCenter]removeObserver:self name:m_settingDict[KEY_IDENTITY] object:nil];
            
            [self writeLogLine:MESSAGE_TEARDOWN];
            
            [m_settingDict removeAllObjects];
            
            //        if (m_bootFromApp) {
            //
            //        } else {
            //            exit(0);
            //        }
            return;
        }
    }
    
}

- (void) ignite {
    [self callParent:S2_EXEC_IGNITED];
    
    NSString * entryId = [KSMessenger generateMID];
    
    NSString * entryRequestMessage = [[NSString alloc] initWithFormat:@"ss@getAllFilePath:{\"anchor\":\"build.gradle\",\"header\":\"-entry \"}->(paths|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\"}->showAtLog:{\"message\":\"entry...%@\"}->showStatusMessage:{\"message\":\"entry...%@\"}", entryId, entryId];

    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":entryRequestMessage} deliverImmediately:YES];
    
}

/**
 エントリー受付
 ST側からの近況コード一式を受け取る
 
 エントリー失敗はログに出る。
 */
- (void) entry:(NSString * )listSource {
    NSArray * targettedSuffixArray = @[@"scala", @"gradle"];
    [self callParent:S2_EXEC_USER_ENTRIED];
    
    [m_pulling removeAllObjects];
    
    //start pull source
    NSArray * pathArray = [listSource componentsSeparatedByString:@","];
    for (NSString * path in pathArray) {

        NSString * suffix = [path pathExtension];

        if ([targettedSuffixArray containsObject:suffix]) {
            [m_codeDict setValue:@"" forKey:path];
            [m_pulling addObject:[self emitPull:path withIdentity:path]];
        }
    }
    
    if ([m_codeDict count] == 0) {
        NSLog(@"no compilation target file contains");
    }
}

- (NSString * ) emitPull:(NSString * )sourcePath withIdentity:(NSString * )identity {
    //SSへのリクエストを組み立てる。
    NSString * pullIdentity = [KSMessenger generateMID];
    NSString * message = [[NSString alloc]initWithFormat:@"ss@readFileData:{\"path\":\"%@\"}->(data|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\",\"header\":\"-update:%@ \"}->showAtLog:{\"message\":\"entry:%@\"}->showStatusMessage:{\"message\":\"entry:%@\"}", sourcePath, identity, pullIdentity, pullIdentity];

    NSLog(@"request is %@", message);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":message} deliverImmediately:YES];
    
    [self callParent:S2_EXEC_PULLING];
    return pullIdentity;
}

- (void) compile:(NSString * )execs {
    NSArray * latestPathsArray = [execs componentsSeparatedByString:@","];
    
    //limit valid path by extension
    NSArray * validExtensions = @[@"scala", @"gradle"];
    
    bool isValid = false;
    
    NSMutableArray * validPathsArray = [[NSMutableArray alloc]init];
    for (NSString * path in latestPathsArray) {
        NSString * extension = [path pathExtension];
        if ([validExtensions containsObject:extension]) {
            [validPathsArray addObject:path];
            if ([extension isEqualToString:@"gradle"]) isValid = true;
        }
    }
    
    if (!isValid) return;
    
    //合致するもの以外を消す
    NSArray * keysList = [NSArray arrayWithArray:[m_codeDict allKeys]];
    for (NSString * path in keysList) {
        if ([validPathsArray containsObject:path]) {
            
        } else {
            [m_codeDict removeObjectForKey:path];
        }
    }
    
    NSString * currentCompileBasePath;
    //build.gradleを探し出す
    for (NSString * path in validPathsArray) {
        if ([[path lastPathComponent] isEqualToString:@"build.gradle"]) {
            currentCompileBasePath = [[NSString alloc]initWithString:path];
        }
    }
    
    if (currentCompileBasePath) {
        
    } else {
        NSLog(@"build.gradleが含まれていない");
        return;
    }
    
    NSLog(@"m_codeDict  %@", m_codeDict);
    //特定のフォルダに吐く
    
    
    //特定のファイルのScalaをコンパイルする
    [self compileScalaAt:@"/Users/mondogrosso/Desktop/HelloWorld/build.gradle"];
}

- (void) compileScalaAt:(NSString * )compileBasePath {
    [self callParent:S2_EXEC_COMPILE_START];
    
    NSArray * currentParams = @[@"--daemon", @"-b", compileBasePath, @"build", @"-i"];
    NSTask * compileTask = [[NSTask alloc]init];
    
    [compileTask setLaunchPath:@"/usr/local/bin/gradle"];
    [compileTask setArguments:currentParams];
    
    NSPipe * currentOut = [[NSPipe alloc]init];
    
    [compileTask setStandardOutput:currentOut];
    
    NSTask * nnotifTask = [[NSTask alloc]init];
    [nnotifTask setLaunchPath:@"/Users/mondogrosso/Desktop/S2/tool/nnotif"];
    [nnotifTask setArguments:@[@"-t", @"GRADLENOTIFY_IDENTITY", @"--ignorebl"]];
    
    [nnotifTask setStandardInput:currentOut];
    
    [compileTask launch];
    [nnotifTask launch];
    
    [m_tasks addObject:compileTask];
    [m_tasks addObject:nnotifTask];
}

- (NSString * ) currentWorkPath {
    NSString * workPath = @"./work";
    return [[NSString alloc]initWithFormat:@"%@", workPath];
}

- (void) removeFiles {
    //全部消す
    NSString * workPath = [self currentWorkPath];
    NSFileManager * fMan = [[NSFileManager alloc]init];
    NSError * error;
    
    for (NSString * file in [fMan contentsOfDirectoryAtPath:workPath error:&error]) {
        
        NSString * removeTargetFilePath = [workPath stringByAppendingPathComponent:file];
        BOOL success = [fMan removeItemAtPath:removeTargetFilePath error:&error];
    }
}

- (void) generateFiles:(NSDictionary * )pathAndSources {
    NSString * currentBuildPath = [self currentWorkPath];
    
    NSError * error;
    NSFileManager * fMan = [[NSFileManager alloc]init];
    [fMan createDirectoryAtPath:currentBuildPath withIntermediateDirectories:YES attributes:nil error:&error];
    
    
    //ファイル出力
    NSString * targetPath;
    for (NSString * path in [pathAndSources allKeys]) {
        //フォルダ生成
        targetPath = [NSString stringWithFormat:@"%@%@", currentBuildPath, path];
        [fMan createDirectoryAtPath:[targetPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
        
        //ファイル生成
        bool result = [fMan createFileAtPath:targetPath contents:[pathAndSources[path] dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
        
        NSFileHandle * writeHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        [writeHandle writeData:[pathAndSources[path] dataUsingEncoding:NSUTF8StringEncoding]];
    }
}


- (void) reset {
    //既存タスクを削除
    for (NSTask * currentTask in m_tasks) {
        [currentTask terminate];
    }
    
}


/**
 output
 */
- (void) writeLogLine:(NSString * )message {
    if (m_writeHandle) {
        NSString * linedMessage = [NSString stringWithFormat:@"%@\n", message];
        [m_writeHandle writeData:[linedMessage dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

/**
 outputのセット
 */
- (void) setOutput:(NSString * )path {
    NSFileManager * fileManager = [NSFileManager defaultManager];
    
    //存在しても何も言わないので、先に存在チェック
    NSFileHandle * readHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    
    //ファイルが既に存在しているか
    if (readHandle) {
        NSLog(@"output-target file already exist, we overwrite.");
    }
    
    bool result = [fileManager createFileAtPath:path contents:nil attributes:nil];
    
    NSAssert1(result, @"the output-file:%@ cannot generate or append", path);
    
    if (result) {
        m_writeHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
}

- (void) callParent:(int)messageId {
    if ([messenger hasParent]) {
        [messenger callParent:messageId, nil];
    }
}

- (void) close {
    [self reset];
    [self callParent:S2_EXEC_EXITED];
    [messenger closeConnection];
}

@end
