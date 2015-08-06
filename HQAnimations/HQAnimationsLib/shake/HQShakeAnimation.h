//
//  HQShakeAnimation.h
//  HQAnimations
//
//  Created by qianhongqiang on 15/8/6.
//  Copyright (c) 2015年 QianHongQiang. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface HQShakeAnimation : CAKeyframeAnimation

//返回参数已经配置好的弹动
+(instancetype)shake;

+(instancetype)shakeAnimationWithKeyPath:(NSString *)keyPath
                              duration:(CFTimeInterval)duration
                               tension:(double)tension
                              velocity:(double)velocity
                             fromValue:(double)fromValue
                               toValue:(double)toValue;

@end
