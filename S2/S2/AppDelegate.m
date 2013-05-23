//
//  AppDelegate.m
//  S2
//
//  Created by sassembla on 2013/05/21.
//  Copyright (c) 2013年 KISSAKI Inc,. All rights reserved.
//

#import "AppDelegate.h"

#define S2_IDENTITY (@"S2_IDENTITY")

@implementation AppDelegate {
    NSMutableDictionary * m_settingDict;
    
    NSFileHandle * m_writeHandle;
    
    bool m_bootFromApp;
    NSMutableArray * m_bufferedOutput;
    NSMutableArray * m_runningTasks;
    
    
    //s2 specific
    NSMutableDictionary * m_codeDict;
}


- (id) initWithArgs:(NSDictionary * )dict {
    if (dict[KEY_VERSION]) NSLog(@"nnotifd version:%@", VERSION);
    
    if (self = [super init]) {
        m_bootFromApp = false;
        if (dict[DEBUG_BOOTFROMAPP]) {
            m_bootFromApp = true;
        }
        
        if (true) {
            m_settingDict = [[NSMutableDictionary alloc]initWithDictionary:@{KEY_IDENTITY:S2_IDENTITY}];
            
            [[NSDistributedNotificationCenter defaultCenter]addObserver:self selector:@selector(receiver:) name:S2_IDENTITY object:nil];
            
            if (dict[KEY_OUTPUT]) {
                [self setOutput:dict[KEY_OUTPUT]];
                [m_settingDict setValue:dict[KEY_OUTPUT] forKey:KEY_OUTPUT];
                [self writeLogLine:MESSAGE_LAUNCHED];
            }
            
            //init with stopped
            [m_settingDict setValue:[[NSNumber alloc]initWithInt:STATUS_STOPPED] forKey:KEY_CONTROL];
            
            if (dict[KEY_EXECUTE]) {
                NSLog(@"cannot execute on launch. inputted executes are ignored.");
                [self writeLogLine:MESSAGE_EXECUTE_IGNOREDONLAUNCH];
            }
            
            int initializedStatus = STATUS_STOPPED;
            
            if (true) {
                initializedStatus = [self setServe:CODE_START];
            }
            
            [m_settingDict setValue:[[NSNumber alloc]initWithInt:initializedStatus] forKey:KEY_CONTROL];
        }
        
        m_codeDict = [[NSMutableDictionary alloc]init];
    }
    return self;
}

/**
 serve control
 */
- (int) setServe:(NSString * )code {
    int status = [m_settingDict[KEY_CONTROL] intValue];
    
    if ([code isEqualToString:CODE_START]) {
        switch (status) {
            case STATUS_RUNNING:{
                NSAssert(false, @"already running, %@", m_settingDict);
                break;
            }
                
            case STATUS_STOPPED:{
                [m_settingDict setValue:[NSNumber numberWithInt:STATUS_RUNNING] forKey:KEY_CONTROL];
                
                [self writeLogLine:MESSAGE_SERVING];
                
                return STATUS_RUNNING;
            }
                
            default:
                break;
        }
    }
    
    if ([code isEqualToString:CODE_STOP]) {
        switch (status) {
            case STATUS_RUNNING:{
                [m_settingDict setValue:[NSNumber numberWithInt:STATUS_STOPPED] forKey:KEY_CONTROL];
                
                [self writeLogLine:MESSAGE_STOPSERVING];
                
                return STATUS_STOPPED;
            }
                
            case STATUS_STOPPED:{
                return STATUS_STOPPED;
            }
                
            default:
                break;
        }
    }
    
    return -1;
}

- (void) receiver:(NSNotification * )notif {
    NSDictionary * dict = [notif userInfo];
    NSLog(@"dict%@", dict);
    [self writeLogLine:[NSString stringWithFormat:@"%@%@", MESSAGE_RECEIVED, dict]];
    
    //コマンドライン動作を行う
    if (dict[S2_MANIPULATE]) {
        NSString * execs = [[NSString alloc]initWithString:dict[S2_MANIPULATE]];
        if ([execs hasPrefix:S2_HEADER]) {
            //まずはJSONとそれ以外に分離する
            NSArray * execAndJSONArray = [[NSArray alloc]initWithArray:[execs componentsSeparatedByString:S2_JSON_PARTITION]];
            
            //残った部分をコマンドラインとして処理する
            NSArray * execArray = [[NSArray alloc]initWithArray:[execAndJSONArray[0] componentsSeparatedByString:S2_SPACE]];
            
            if (1 < [execArray count]) {
                NSArray * subarray = [execArray subarrayWithRange:NSMakeRange(1, [execArray count]-1)];
                if (1 < [execAndJSONArray count]) {
                    [self readInput:subarray withParam:execAndJSONArray[1]];
                } else {
                    [self readInput:subarray withParam:nil];
                }
            }
        }
        
        if ([execs hasPrefix:KEY_COMPILE]) {
            NSArray * headAndBody = [execs componentsSeparatedByString:@" "];
            NSArray * latestPathsArray = [headAndBody[1] componentsSeparatedByString:@","];

            //limit valid path by extension
            NSArray * validExtensions = @[@"scala", @"gradle"];

            NSMutableArray * validPathsArray = [[NSMutableArray alloc]init];
            for (NSString * path in latestPathsArray) {
                NSString * extension = [path pathExtension];
                if ([validExtensions containsObject:extension]) {
                    [validPathsArray addObject:path];
                }
            }
            
            //合致するもの以外を消す
            NSArray * keysList = [NSArray arrayWithArray:[m_codeDict allKeys]];
            for (NSString * path in keysList) {
                if ([validPathsArray containsObject:path]) {
                    
                } else {
                    [m_codeDict removeObjectForKey:path];
                }
            }
        
            NSLog(@"m_codeDict  %@", m_codeDict);
        }
        
        //updateはここで処理する -update:path sourcecode
        if ([execs hasPrefix:KEY_UPDATE]) {
            
            NSArray * head = [[execs componentsSeparatedByString:@" "] subarrayWithRange:NSMakeRange(0,1)];

            NSString * path = [head[0] componentsSeparatedByString:@":"][1];
//            NSString * headAndSpace = [[NSString alloc]initWithFormat:@"%@%@", head, @" "];
            
            //remove header from code
//            NSRange rangeOfSubstring = [execs rangeOfString:headAndSpace];
            NSString * source = [execs substringFromIndex:([head[0] length]+1)];
            NSLog(@"path %@", path);
            NSLog(@"source %@", source);
            
            //update code
            [m_codeDict setValue:source forKey:path];
        }
    }
    
}



- (void) readInput:(NSArray * )execArray withParam:(NSString * )jsonParam {
    
    NSMutableDictionary * argsDict = [[NSMutableDictionary alloc]init];
    
    for (int i = 0; i < [execArray count]; i++) {
        NSString * keyOrValue = execArray[i];
        
        if ([keyOrValue hasPrefix:KEY_PERFIX]) {
            NSString * key = keyOrValue;
            
            // get value
            if (i + 1 < [execArray count]) {
                NSString * value = execArray[i + 1];
                if ([value hasPrefix:KEY_PERFIX]) {
                    [argsDict setValue:@"" forKey:key];
                } else {
                    [argsDict setValue:value forKey:key];
                }
            }
            else {
                NSString * value = @"";
                [argsDict setValue:value forKey:key];
            }
        }
    }
    
    [self writeLogLine:MESSAGE_INPUTRECEIVED];
    
    
    if (0 < [argsDict count]) {
        [self execute:argsDict withParam:jsonParam];
    }
}

/**
 入力を元に、動作を変更する
 */
- (void) execute:(NSDictionary * )argsDict withParam:(NSString * )jsonParam {
    if (argsDict[KEY_NOTIFID]) {
        [self writeLogLine:[[NSString alloc]initWithFormat:@"%@%@",MESSAGE_MESSAGEID_RECEIVED, argsDict[KEY_NOTIFID]]];
    }
    
    if (argsDict[KEY_OUTPUT]) {
        [self setOutput:argsDict[KEY_OUTPUT]];
    }
    
    if (argsDict[KEY_KILL]) {
        [[NSDistributedNotificationCenter defaultCenter]removeObserver:self name:m_settingDict[KEY_IDENTITY] object:nil];
        
        for (NSTask * task in m_runningTasks) {
            if ([task isRunning]) [task terminate];
        }
        
        [self writeLogLine:MESSAGE_TEARDOWN];
        
        [m_settingDict removeAllObjects];
        
        if (m_bootFromApp) {
            
        } else {
            exit(0);
        }
        return;
    }
    
    int latestStatus = [m_settingDict[KEY_CONTROL] intValue];
    
    if (argsDict[KEY_CONTROL]) {
        latestStatus = [self setServe:argsDict[KEY_CONTROL]];
        [self writeLogLine:MESSAGE_UPDATED];
    }
    if (argsDict[KEY_EXECUTE]) {
        [self writeLogLine:[NSString stringWithFormat:@"%@%@", MESSAGE_PREEXECUTE, jsonParam]];
        
        switch (latestStatus) {
            case STATUS_STOPPED:{
                [self writeLogLine:MESSAGE_EXECUTE_IGNOREDBEFORESTART];
                break;
            }
            case STATUS_RUNNING:{
                //read JSON
                [self executeJson:jsonParam];
                
                break;
            }
                
            default:
                break;
        }
    }
    
    if (argsDict[KEY_IGNITE]) {
        //ここで、リストの受け取り、そのリストの内容をすべてgetするためのリクエストを出す
        NSString * pathsListStr = argsDict[KEY_IGNITE];
        NSArray * pathArray = [pathsListStr componentsSeparatedByString:@","];
        
        NSArray * targettedSuffixArray = @[@"scala", @"gradle"];
        
        for (NSString * path in pathArray) {
            
            NSString * suffix = [path pathExtension];
            
            if ([targettedSuffixArray containsObject:suffix]) {
                [m_codeDict setValue:@"" forKey:path];
                [self emitPullRequestMessage:path withIdentity:path];
            }
        }
    }
   
}


- (void) emitPullRequestMessage:(NSString * )sourcePath withIdentity:(NSString * )identity {
    //SSへのリクエストを組み立てる。
    NSString * message = [[NSString alloc]initWithFormat:@"%@%@%@%@%@", @"ss@readFileData:{\"path\":\"", sourcePath, @"\"}->(data|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\",\"header\":\"-update:",identity, @" \"}"];

    NSLog(@"request is %@", message);
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":message} deliverImmediately:YES];
}


- (void) compile {
    NSArray * currentParams = @[@"--daemon", @"-b", @"/Users/mondogrosso/Desktop/HelloWorld/build.gradle", @"build", @"-i"];
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
}


- (bool) isRunning {
    return [m_settingDict[KEY_CONTROL] intValue] == STATUS_RUNNING;
}

- (NSString * )identity {
    return m_settingDict[KEY_IDENTITY];
}

- (void) executeJson:(NSString * )jsonStr {
    NSData * jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    
    //JsonからArray、辞書は受け付けない。pipeを使うのを念頭においているので、ただ連結して実行するだけの形式がベスト。
    NSError * err;
    NSArray * jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&err];
    
    if (err) {
        [self writeLogLine:[NSString stringWithFormat:@"%@%@ because of:%@", MESSAGE_EXECUTE_FAILED, jsonStr, err]];
    } else {
        NSMutableArray * tasks = [[NSMutableArray alloc]init];
        NSMutableArray * currentExec = [[NSMutableArray alloc]init];
        NSMutableArray * currentParams = [[NSMutableArray alloc]init];
        
        NSMutableArray * currentOut = [[NSMutableArray alloc]init];
        
        for (NSString * execOrParam in jsonArray) {
            
            
            if ([execOrParam isEqualToString:DEFINE_PIPE]) {//pipe
                
                if ([currentExec count] == 0) {
                    [self writeLogLine:[NSString stringWithFormat:@"%@%@ because of:%@", MESSAGE_EXECUTE_FAILED, [jsonArray componentsJoinedByString:S2_SPACE], FAILBY_NOEXEC]];
                    return;
                }
                
                //task gen
                NSTask * task = [[NSTask alloc]init];
                [task setLaunchPath:currentExec[0]];
                [task setArguments:currentParams];
                
                if (0 < [currentOut count]) {
                    [task setStandardInput:currentOut[0]];
                }
                
                NSPipe * pipe = [[NSPipe alloc]init];
                //続きがあるので、outを用意しておく
                [task setStandardOutput:pipe];
                
                [tasks addObject:task];
                
                //reset params
                [currentExec removeAllObjects];
                [currentParams removeAllObjects];
                [currentOut removeAllObjects];
                
                //ready pipe for next
                [currentOut addObject:pipe];
                continue;
            }
            
            //not single "|"
            NSRange range = [execOrParam rangeOfString:DEFINE_PIPE];
            if (range.location != NSNotFound) {
                [self writeLogLine:[NSString stringWithFormat:@"%@%@ because of:%@", MESSAGE_EXECUTE_FAILED, [jsonArray componentsJoinedByString:S2_SPACE], FAILBY_NOSPACEWHILEPIPE]];
                return;
            }
            
            {
                //exec本体かパラメータ
                if ([currentExec count] == 0) {
                    [currentExec addObject:execOrParam];
                } else {
                    [currentParams addObject:execOrParam];
                }
            }
        }
        
        //最後の一つのtask genを行えば、OKなはず。
        NSTask * lastTask = [[NSTask alloc]init];
        [lastTask setLaunchPath:currentExec[0]];
        [lastTask setArguments:currentParams];
        
        //存在すれば、outを受ける
        if (0 < [currentOut count]) [lastTask setStandardInput:currentOut[0]];
        [tasks addObject:lastTask];
        @try {
            for (NSTask * task in tasks) {
                [task launch];
            }
            
            [self writeLogLine:[NSString stringWithFormat:@"%@%@",MESSAGE_EXECUTE_LAUNCHED, [jsonArray componentsJoinedByString:S2_SPACE]]];
        }
        @catch (NSException * exception) {
            [self writeLogLine:[NSString stringWithFormat:@"%@%@ because of:%@", MESSAGE_EXECUTE_FAILED, [jsonArray componentsJoinedByString:S2_SPACE], exception]];
        }
        @finally {
            [m_runningTasks removeAllObjects];
            m_runningTasks = [[NSMutableArray alloc]init];
            for (NSTask * task in tasks) {
                if ([task isRunning]) {
                    [m_runningTasks addObject:task];
                }
            }
        }
        
    }
}



//output

- (void) writeLogLine:(NSString * )message {
    if (m_bufferedOutput) [m_bufferedOutput addObject:message];
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
        m_bufferedOutput = [[NSMutableArray alloc]init];
        m_writeHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
}

/**
 output ファイルの文字列を改行コードごと総て吐き出す
 */
- (NSArray * )bufferedOutput {
    return m_bufferedOutput;
}
- (NSArray * )runningTasks {
    return m_runningTasks;
}

- (NSString * )outputPath {
    NSAssert(m_settingDict[KEY_OUTPUT], @"output target path is not set yet.");
    return m_settingDict[KEY_OUTPUT];
}




@end
