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



@interface S2Tests : SenTestCase

@end

@implementation S2Tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}


/**
 どうやってテストするか。まず、発射側をつくらんとな。
 */
- (void) test {
    
    STFail(@"Unit tests are not implemented yet in S2Tests");
}

@end
