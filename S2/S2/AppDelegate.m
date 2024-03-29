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
        
        //initialize workPath
        [self removeFilesAtWorkPath];
        
        m_tasks = [[NSMutableArray alloc]init];
        m_pulling = [[NSMutableArray alloc]init];
    }
    return self;
}


- (void) receiver:(NSNotification * )notif {
    [self writeLogLine:@"received"];
    
    NSDictionary * dict = [messenger tagValueDictionaryFromNotification:notif];
    [self writeLogLine:[messenger myName]];
    [self writeLogLine:[messenger myMID]];
    
    switch ([messenger execFrom:[messenger myName] viaNotification:notif]) {
        case S2_COMPILING:{
            NSAssert(dict[@"processes"], @"processes required");
            NSArray * tasks = dict[@"processes"];

            //0番固定
            NSTask * primaryTask = tasks[0];
            
            //ここで特定タスクのみ待つ
            [primaryTask waitUntilExit];
            
            
            //終了したので、消す
            [m_tasks removeObject:tasks];
            [self writeLogLine:@"executed"];
            [self callParent:S2_EXEC_COMPILE_FINISHED];            
            break;
        }
            
        default:
            break;
    }
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
        
        //entry -entry paths
        if ([head isEqualToString:KEY_ENTRY]) {
            [self entry:body];
        }
        
        //update -update:path sourcecode
        if ([head hasPrefix:KEY_UPDATE]) {
            [self update:[head componentsSeparatedByString:@":"][1] withSource:body];
        }
        
        if ([head isEqualToString:KEY_COMPILE] || [head isEqualToString:KEY_COMPILE_DUMMY]) {
            [self compile:body];
        }

        if ([head isEqualToString:KEY_EXECUTE]) {
            [self execute:body];
            [self callParent:S2_EXEC_EXECUTE];
        }
    }
    
}

/**
 着火
 */
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
            [self pullClientCode:path];
        }
    }
    
    if ([m_codeDict count] == 0) {
        NSLog(@"no compilation target file contains");
    }
}

/**
 STへのコード送付リクエストを出す
 */
- (NSString * ) emitPull:(NSString * )sourcePath withIdentity:(NSString * )identity {
    //SSへのリクエストを組み立てる。
    NSString * message = [[NSString alloc]initWithFormat:@"ss@readFileData:{\"path\":\"%@\"}->(data|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\",\"header\":\"-update:%@ \"}->showAtLog:{\"message\":\"pulled:%@\"}->showStatusMessage:{\"message\":\"pulled:%@\"}", sourcePath, identity, sourcePath, sourcePath];

    NSLog(@"request is %@", message);
    
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":message} deliverImmediately:YES];
    
    [self callParent:S2_EXEC_PULLING];
    return sourcePath;
}

- (void) update:(NSString * )path withSource:(NSString * )source {
    [self callParent:S2_EXEC_UPDATED];
    
    //update code
    [m_codeDict setValue:source forKey:path];
    
    [m_pulling removeObject:path];
    
    //途中でソースコードが増えたりした場合には無効な通知
    if ([m_pulling count] == 0) {
        [self callParent:S2_EXEC_PULLED_ALL];
    }

}

/**
 コンパイル
 */
- (void) compile:(NSString * )body {
    
    //すでにコンパイル中であったら即停止
    [self reset];
    
    if (body) {
        NSLog(@"compile start");
    } else {
        NSLog(@"compile loading");
        NSString * compileId = [KSMessenger generateMID];
        [self callParent:S2_EXEC_COMPILE_INFOREQUST];
        NSString * entryRequestMessage = [[NSString alloc] initWithFormat:@"ss@getAllFilePath:{\"anchor\":\"build.gradle\",\"header\":\"-compile \"}->(paths|message)monocastMessage:{\"target\":\"S2Client\",\"message\":\"replace\"}->showAtLog:{\"message\":\"compile push:%@\"}->showStatusMessage:{\"message\":\"entry:%@\"}", compileId, compileId];
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"FROMS2_IDENTITY" object:nil userInfo:@{@"message":entryRequestMessage} deliverImmediately:YES];
        return;
    }

    
    [self callParent:S2_EXEC_COMPILE_READY];
    NSArray * latestPathsArray = [body componentsSeparatedByString:@","];
    
    //limit valid path by extension
    NSArray * validExtensions = @[@"scala", @"gradle"];
    
    
    NSMutableArray * validPathsArray = [[NSMutableArray alloc]init];
    NSString * currentCompileBasePath;
    for (NSString * path in latestPathsArray) {
        NSString * extension = [path pathExtension];
        if ([validExtensions containsObject:extension]) {
            [validPathsArray addObject:path];
            if ([[path lastPathComponent] isEqualToString:@"build.gradle"]) {
                currentCompileBasePath = [[NSString alloc]initWithString:path];
            }
        }
    }

    
    if (currentCompileBasePath) {
     
    } else {
        [self callParent:S2_EXEC_COMPILE_CANCELLED_BY_MISSING_ANCHOR];
        NSLog(@"compile cancelled, no anchor");
        return;
    }

    NSLog(@"compile start1");
    
    
    //合致するもの以外を消す
    /*
     b,c,d
     c,d,e
     e->remove
     b->pull
     */
    NSArray * keysList = [NSArray arrayWithArray:[m_codeDict allKeys]];
    for (NSString * path in keysList) {
        //from memory
        if ([validPathsArray containsObject:path]) {
            //
        } else {
            //ファイルからも消される
            [m_codeDict removeObjectForKey:path];
        }
    }
    
    //memoryとlistの合致を見て、listにあってmemoryに無い物があるかどうか
    NSSet * memorySet = [NSSet setWithArray:keysList];
    NSMutableSet * latestListSet = [NSMutableSet setWithArray:validPathsArray];
    
    [latestListSet minusSet:memorySet];

    if (0 < [latestListSet count]) {
        [self callParent:S2_EXEC_COMPILE_POSTPONED_BY_PULL];
        for (NSString * path in latestListSet) {
            [self pullClientCode:path];
        }
        return;
    }
    
        
    //特定のフォルダに吐く
    [self generateFiles:m_codeDict];

    NSLog(@"currentCompileBasePath %@", currentCompileBasePath);
    //特定のファイルのScalaをコンパイルする
    [self compileScalaAt:m_codeDict];
}


- (void) compileScalaAt:(NSDictionary * )codeDict {
    //Gradleでのコンパイル一択、だが、弄る事も出来る筈。
    [self callParent:S2_EXEC_COMPILE_START];
    [self writeLogLine:@"compile!"];

    NSArray * compileTaskArray = [self gradleCompile:codeDict];
    
    [m_tasks addObject:compileTaskArray];
    
    [messenger callMyself:S2_COMPILING,
     [messenger tag:@"processes" val:compileTaskArray],
     [messenger withDelay:CHECK_INTERVAL],
     nil];
    
    [self writeLogLine:@"compile! task start"];
    [self writeLogLine:[messenger myName]];
    [self writeLogLine:[messenger myMID]];
}

/**
 より高確率で起こる！
 */
- (NSArray * )dummyCompile:(NSDictionary * )codeDict {
        
    NSTask * compileTask = [[NSTask alloc]init];
    
    [compileTask setLaunchPath:@"/bin/pwd"];
    
    NSPipe * currentOut = [[NSPipe alloc]init];
    
    [compileTask setStandardOutput:currentOut];
    
    NSTask * nnotifTask = [[NSTask alloc]init];
    
    [nnotifTask setLaunchPath:@"/Users/mondogrosso/Desktop/S2/tool/nnotif"];
    [nnotifTask setArguments:@[@"-t", @"S2_OUT", @"--ignorebl"]];
    
    [nnotifTask setStandardInput:currentOut];
    
    [compileTask launch];
    [nnotifTask launch];
    
    NSArray * taskArray = @[compileTask, nnotifTask];
    return taskArray;
}


/**
 Gradleでのコンパイル
 */
- (NSArray * ) gradleCompile:(NSDictionary * )codeDict {
    NSString * currentCompileBasePath;
    //build.gradleを探し出す
    for (NSString * path in [codeDict allKeys]) {
        if ([[path lastPathComponent] isEqualToString:@"build.gradle"]) {
            currentCompileBasePath = [[NSString alloc]initWithString:path];
        }
    }
    
    if (currentCompileBasePath) {
        
    } else {
        [self writeLogLine:@"compile abort, no build targeting file"];
        return nil;
    }
    
    
    NSString * compileBasePath = [NSString stringWithFormat:@"%@%@", [self currentWorkPath], currentCompileBasePath];
    [self writeLogLine:compileBasePath];
    
    
    NSArray * currentParams = @[@"--daemon", @"-b", compileBasePath, @"build", @"-i"];
    
    NSTask * compileTask = [[NSTask alloc]init];
    
    [compileTask setLaunchPath:@"/usr/local/bin/gradle"];
    [compileTask setArguments:currentParams];
    
    NSPipe * currentOut = [[NSPipe alloc]init];
    
    [compileTask setStandardOutput:currentOut];
    
    NSTask * nnotifTask = [[NSTask alloc]init];
    
    [nnotifTask setLaunchPath:@"/Users/mondogrosso/Desktop/S2/tool/nnotif"];
    [nnotifTask setArguments:@[@"-t", @"S2_OUT", @"--ignorebl"]];
    
    [nnotifTask setStandardInput:currentOut];
    
    [compileTask launch];
    [nnotifTask launch];
    
    NSArray * taskArray = @[compileTask, nnotifTask];
    return taskArray;
}




/**
 パスを受け取り、そのファイルを直接ワークスペースにコピーしてきて、コンパイルを実行する
 */
- (void) execute:(NSString * )paths {
    NSArray * pathsArray = [paths componentsSeparatedByString:@","];
    
    //読む
    for (NSString * path in pathsArray) {
        NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:path];
        NSData * data = [handle readDataToEndOfFile];
        NSString * string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [m_codeDict setValue:string forKey:path];
    }
    
    //codeDictが完成したので、コンパイルに入る
    [self generateFiles:m_codeDict];
    
    //ビルド
    [self compileScalaAt:m_codeDict];
}



- (NSString * ) currentWorkPath {
    NSString * workPath = @"./work";
    return [[NSString alloc]initWithFormat:@"%@", workPath];
}





- (void) removeFilesAtWorkPath {
    //全部消す
    NSString * workPath = [self currentWorkPath];
    NSFileManager * fMan = [[NSFileManager alloc]init];
    NSError * error;
    
    for (NSString * file in [fMan contentsOfDirectoryAtPath:workPath error:&error]) {
        
        NSString * removeTargetFilePath = [workPath stringByAppendingPathComponent:file];
        BOOL success = [fMan removeItemAtPath:removeTargetFilePath error:&error];
        
        if (!success) {
            NSLog(@"消すのに失敗");
        }
    }
}

/**
 ファイル作成(メモリ上のものを使う場合は不要)
 */
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

        if (result) {
            NSLog(@"generated:%@", targetPath);
        } else {
            NSLog(@"fail to generate:%@", targetPath);
        }
        
        NSFileHandle * writeHandle = [NSFileHandle fileHandleForUpdatingAtPath:targetPath];
        [writeHandle writeData:[pathAndSources[path] dataUsingEncoding:NSUTF8StringEncoding]];
    }
}


- (void) reset {
    //既存タスクを削除
    for (NSArray * currentTaskArray in m_tasks) {
        for (NSTask * currentTask in currentTaskArray) {
            [currentTask terminate];
        }
    }
}

/**
 対象のファイルを、クライアント側から取得する
 */
- (void) pullClientCode:(NSString * )path {
    [m_codeDict setValue:@"" forKey:path];
    [m_pulling addObject:[self emitPull:path withIdentity:path]];
}

/**
 workPathから、現在出力されている特定名称のファイルの内容を取り出す
 */
- (NSString * )cachedFile:(NSString * )path {
    NSAssert(m_codeDict[path], @"not contained in cache:%@      maybe not yet compiled", path);
    NSString * targetPath = [NSString stringWithFormat:@"%@%@", [self currentWorkPath], path];

    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:targetPath];
    NSAssert(handle, @"handle is nil");
    
    NSData * data = [handle readDataToEndOfFile];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSArray * ) currentTasks {
    return [NSArray arrayWithArray:m_tasks];
}

/**
 output
 */
- (void) writeLogLine:(NSString * )message {
    NSLog(@"log:%@", message);
    if (m_writeHandle) {
        NSString * linedMessage = [NSString stringWithFormat:@"S2:%@\n", message];
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
    [self writeLogLine:@"closing"];
    [self writeLogLine:[messenger myName]];
    [self writeLogLine:[messenger myMID]];
    
    [self reset];
    [self callParent:S2_EXEC_EXITED];
    [messenger closeConnection];
}

@end
