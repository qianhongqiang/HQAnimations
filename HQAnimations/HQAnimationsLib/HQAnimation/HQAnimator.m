//
//  HQAnimator.m
//  HQAnimations
//
//  Created by qianhongqiang on 2017/5/11.
//  Copyright © 2017年 QianHongQiang. All rights reserved.
//

#import "HQAnimator.h"
#import "HQAnimationState.h"
#import "HQBasicAnimation.h"
#import <QuartzCore/QuartzCore.h>
#import <libkern/OSAtomic.h>
#import <UIKit/UIKit.h>

@interface HQAnimatorItem : NSObject

@property (nonatomic, strong) HQAnimation *animation;

@property (nonatomic, weak) id obj;

@property (nonatomic, copy) NSString *key;

@end

@implementation HQAnimatorItem

@end

@interface HQAnimator ()

@property (nonatomic) CADisplayLink *display;
@property (nonatomic, strong) NSMutableDictionary<id,NSMutableDictionary<NSString *,HQAnimation *> *> *animationsDict;
@property (nonatomic, strong) NSMutableArray<HQAnimatorItem *> *itemArray;
@property (nonatomic) OSSpinLock lock;

@end

@implementation HQAnimator

static inline void spinLock(OSSpinLock *lock,dispatch_block_t block)
{
    OSSpinLockLock(lock);
    if (block) block();
    OSSpinLockUnlock(lock);
}

+ (id)sharedAnimator
{
    static HQAnimator* _animator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _animator = [[HQAnimator alloc] init];
    });
    return _animator;
}

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    
    _animationsDict = [NSMutableDictionary dictionary];
    _itemArray = [NSMutableArray array];
    _lock = OS_SPINLOCK_INIT;
    [self.display addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    return self;
}

- (void)lock:(dispatch_block_t)block
{
    spinLock(&_lock,block);
}

- (void)_update:(CADisplayLink *)link
{
    CFTimeInterval current = CACurrentMediaTime();
    [self _renderWithTime:current];
}

- (void)_renderWithTime:(CFTimeInterval)time
{
    [self _renderWithTime:time items:_itemArray];
}

- (void)_renderWithTime:(CFTimeInterval)time items:(NSArray<HQAnimatorItem *> *)items
{
    for (HQAnimatorItem *item in items) {
        [self _renderWithTime:time item:item];
    }
}

- (void)_renderWithTime:(CFTimeInterval)time item:(HQAnimatorItem *)item
{
    HQAnimation *animation = item.animation;
    if ([animation.animationState isStart]) {
        [animation.animationState applyAnimationTime:item.obj time:time];
        if (animation.animationState.valueType == HQAnimationValueTypeRect) {
            
            NSValue *current = animation.animationState.currentValue;
            
            [item.obj setFrame:[current CGRectValue]];
        }
    }else {
        [animation.animationState startIfNeed];
    }
    
}

- (void)addAnimation:(HQAnimation *)anim forObject:(id)obj key:(NSString *)key
{
    NSMutableDictionary<NSString *,HQAnimation *> *dict = [self.animationsDict objectForKey:[NSString stringWithFormat:@"%lu",(unsigned long)[obj hash]]];
    if (!dict) {
        dict = [NSMutableDictionary dictionary];
        [self.animationsDict setObject:dict forKey:[NSString stringWithFormat:@"%lu",(unsigned long)[obj hash]]];
    } else {
        HQAnimation *existedAnim = [dict objectForKey:key];
        if (existedAnim) {
            if (existedAnim == anim) return;
            [self removeAnimationForObject:obj key:key cleanupDict:NO];
        }
    }
    
    HQAnimatorItem *item = [[HQAnimatorItem alloc] init];
    item.animation = anim;
    item.obj = obj;
    item.key = key;
    
    [_itemArray addObject:item];
}

- (void)removeAnimationForObject:(id)obj key:(NSString *)key cleanupDict:(BOOL)cleanupDict
{
    NSMutableDictionary *dict = [self.animationsDict objectForKey:[NSString stringWithFormat:@"%lu",(unsigned long)[obj hash]]];
    if (dict) {
        HQAnimation *animation = [dict objectForKey:key];
        if (animation) {
            [dict removeObjectForKey:key];
            if (dict.count == 0 && cleanupDict) {
                [self.animationsDict removeObjectForKey:obj];
            }
            [self removeAinmatortItemWithAnimation:animation];
        }
        
    }
}

- (void)removeAinmatortItemWithAnimation:(HQAnimation *)anim
{
    [self lock:^{
        if (self.itemArray.count == 0) return;
        NSMutableArray *array = [NSMutableArray array];
        for (HQAnimatorItem *item in self.itemArray) {
            if (item.animation != anim) {
                [array addObject:item];
            }
        }
        self.itemArray = array;
    }];
}

#pragma mark - getter
- (CADisplayLink *)display
{
    if (!_display) {
        _display = [CADisplayLink displayLinkWithTarget:self selector:@selector(_update:)];
        _display.frameInterval = 1;
        _display.paused = NO;
    }
    return _display;
}

@end
