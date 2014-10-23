//
//  ViewController.m
//  AVPlayer Demo
//
//  Created by xuzhaocheng on 14/10/23.
//  Copyright (c) 2014年 Zhejiang University. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

NSString *kTracksKey		= @"tracks";
NSString *kStatusKey		= @"status";
NSString *kRateKey			= @"rate";
NSString *kPlayableKey		= @"playable";

static const NSString *ItemStatusContext;
static const NSString *ItemRateContext;

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;

@property (strong, nonatomic) id timeObserver;

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (nonatomic) float restoreAfterSlideringRate;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self syncUI];
}


- (void)syncUI
{
    [self syncPlayerButton];
    [self syncPlayPauseButtons];
    [self syncSlider];
}

#pragma mark - Play, Pause Buttons
- (void)showPlayButton
{
    self.playButton.hidden = NO;
    self.pauseButton.hidden = YES;
}

- (void)showPauseButton
{
    self.playButton.hidden = YES;
    self.pauseButton.hidden = NO;
}

- (void)setPlayerButtonsEnabled:(BOOL)enabled
{
    self.playButton.enabled = enabled;
    self.pauseButton.enabled = enabled;
}

- (void)syncPlayerButton
{
    if (self.player.currentItem && ([self.player.currentItem status] == AVPlayerItemStatusReadyToPlay)) {
        [self setPlayerButtonsEnabled:YES];
    } else {
        [self setPlayerButtonsEnabled:NO];
    }
}

- (void)syncPlayPauseButtons
{
    if ([self isPlaying]) {
        [self showPauseButton];
    } else {
        [self showPlayButton];
    }
}

#pragma mark - Player
- (CMTime)playerItemDuration
{
    AVPlayerItem *thePlayerItem = [self.player currentItem];
    if (thePlayerItem.status == AVPlayerItemStatusReadyToPlay)
        return([self.playerItem duration]);
    
    return(kCMTimeInvalid);
}

- (BOOL)isPlaying
{
    return self.player.rate;
}

#pragma mark - 
#pragma mark UISlider
#pragma mark -
- (void)syncSlider
{
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        self.slider.minimumValue = 0.0;
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration) && (duration > 0)) {
        float minValue = [self.slider minimumValue];
        float maxValue = [self.slider maximumValue];
        double time = CMTimeGetSeconds([self.player currentTime]);
        [self.slider setValue:(maxValue - minValue) * time / duration + minValue];
    }
}


-(void)initSliderTimer
{
    double interval = .1f;
    
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth([self.slider bounds]);
        interval = 0.5f * duration / width;
    }
    
    /* Update the slider during normal playback. */
    __weak ViewController *weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
                                                                   queue:NULL
                                                              usingBlock: ^(CMTime time) {
                                                                             [weakSelf syncSlider];
                                                                         }];
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

- (void)disableSlider
{
    self.slider.enabled = NO;
}

- (void)enableSlider
{
    self.slider.enabled = YES;
}

#pragma mark - Slider Actions
/* 
 * The user is dragging the movie controller thumb to slider through the movie.
 * 用户开始拖动Slider
 * 记录拖动前player的rate
 * 把rate设为0，停止播放
 * 移除Player的Observer
 */
- (IBAction)beginScrubbing:(id)sender
{
    self.restoreAfterSlideringRate = [self.player rate];
    [self.player setRate:0.f];
    
    /* Remove previous timer. */
    [self removePlayerTimeObserver];
}

/* 
 *The user has released the movie thumb control to stop slide through the movie.
 * 用户松开手指，停止拖动Slider
 * 重新设置Player的Observer
 * 恢复rate
 */
- (IBAction)endScrubbing:(id)sender
{
    if (!self.timeObserver) {
        CMTime playerDuration = [self playerItemDuration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration)) {
            CGFloat width = CGRectGetWidth([self.slider bounds]);
            double tolerance = 0.5f * duration / width;
            
            __weak ViewController *weakSelf = self;
            self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC)
                                                                           queue:dispatch_get_main_queue()
                                                                      usingBlock:^(CMTime time) {
                                                                                     [weakSelf syncSlider];
                                                                                 }];
        }
    }
    
    [self.player setRate:self.restoreAfterSlideringRate ? self.restoreAfterSlideringRate : 0.f];
}

/* 
 * Set the player current time to match the slide position.
 * 用户拖动Slider
 */
- (IBAction)slide:(id)sender
{
    if ([sender isKindOfClass:[UISlider class]]) {
        UISlider *slider = sender;
        
        CMTime playerDuration = [self playerItemDuration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration)) {
            float minValue = [slider minimumValue];
            float maxValue = [slider maximumValue];
            float value = [slider value];
            
            double time = duration * (value - minValue) / (maxValue - minValue);
            
            [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
        }
    }
}

#pragma mark - Prepare to play asset
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    for (NSString *key in requestedKeys) {
        NSError *error;
        AVKeyValueStatus status = [asset statusOfValueForKey:key error:&error];
        if (status == AVKeyValueStatusFailed) {
            [self assetFailedToPrepareForPlayback:error];
            return;
        }
    }
    
    if (!asset.playable) {
        NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
        NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
    }
    
    if (self.playerItem) {
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    [self.playerItem addObserver:self
                      forKeyPath:kStatusKey
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:&ItemStatusContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
        [self.player addObserver:self
                      forKeyPath:kRateKey
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                         context:&ItemRateContext];
    }
    
    if (self.player.currentItem != self.playerItem) {
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        [self.player pause];
        [self syncUI];
    }
    self.slider.value = 0.f;
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:kStatusKey] && context == &ItemStatusContext) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playItemStatusChanged:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
        });
    } else if ([keyPath isEqualToString:kRateKey] && context == &ItemRateContext) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self syncPlayPauseButtons];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)playItemStatusChanged:(AVPlayerItemStatus)status
{
    [self syncPlayPauseButtons];

    switch (status) {
        case AVPlayerStatusReadyToPlay:
            [self syncPlayerButton];
            [self enableSlider];
            [self initSliderTimer];
            break;
        case AVPlayerStatusFailed:
            break;
        case AVPlayerStatusUnknown:
            break;
        default:
            break;
    }
}

#pragma mark - Button Actions
- (IBAction)loadAsset:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://img3.dangdang.com/newimages/music/online/zgx_wmzt.mp3"];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    
    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];
    
    [asset loadValuesAsynchronouslyForKeys:requestedKeys
                         completionHandler:^{
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 [self prepareToPlayAsset:asset withKeys:requestedKeys];
                             });
                         }];
}

- (IBAction)play:(id)sender
{
    [self.player play];
}
- (IBAction)pause:(id)sender
{
    [self.player pause];
}

#pragma mark - Player Notificaton
- (void)playerItemDidReachEnd:(NSNotification *)notification {
    [self.player seekToTime:kCMTimeZero];
}


#pragma mark - Handle Errors
-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncSlider];
    [self disableSlider];
    [self setPlayerButtonsEnabled:NO];
    
    /* Display the error. */
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

@end
