//
//  AgentIdentityInfo.h
//  helpdesk_sdk
//
//  Created by 赵 蕾 on 16/5/5.
//  Copyright © 2016年 hyphenate. All rights reserved.
//

#import "HContent.h"

@interface AgentIdentityInfo : HContent
@property (nonatomic) NSString * agentName;

-(instancetype) initWithValue:(NSString *)value;
@end