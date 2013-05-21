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
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    
    STFail(@"Unit tests are not implemented yet in S2Tests");
}

@end
