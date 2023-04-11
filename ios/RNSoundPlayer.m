//
//  RNSoundPlayer
//
//  Created by Johnson Su on 2018-07-10.
//

#import "RNSoundPlayer.h"

@implementation RNSoundPlayer

static NSString *const EVENT_FINISHED_LOADING = @"FinishedLoading";
static NSString *const EVENT_FINISHED_LOADING_FILE = @"FinishedLoadingFile";
static NSString *const EVENT_FINISHED_LOADING_URL = @"FinishedLoadingURL";
static NSString *const EVENT_FINISHED_PLAYING = @"FinishedPlaying";

RCT_EXPORT_METHOD(playUrl:(NSString *)url) {
    [self prepareUrl:url];
    [self.avPlayer play];
}

RCT_EXPORT_METHOD(loadUrl:(NSString *)url) {
    [self prepareUrl:url];
}

RCT_EXPORT_METHOD(playSoundFile:(NSString *)name ofType:(NSString *)type) {
    NSURL * soundURL = [NSURL URLWithString:name];
    if(!_player2){
        _player2 = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:nil];
        _player2.delegate = self;
        [_player2 play];
    }else if(!_player3){
        _player3 = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:nil];
        _player3.delegate = self;
        [_player3 play];
    }
}

RCT_EXPORT_METHOD(playSoundFileWithDelay:(NSString *)name ofType:(NSString *)type delay:(double)delay) {
    [self mountSoundFile:name ofType:type];
    [self.player playAtTime:(self.player.deviceCurrentTime + delay)];
}

RCT_EXPORT_METHOD(loadSoundFile:(NSString *)name ofType:(NSString *)type) {
    [self mountSoundFile:name ofType:type];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[EVENT_FINISHED_PLAYING, EVENT_FINISHED_LOADING, EVENT_FINISHED_LOADING_URL, EVENT_FINISHED_LOADING_FILE];
}

RCT_EXPORT_METHOD(pause) {
    if (self.player != nil) {
        [self.player pause];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer pause];
    }
}

RCT_EXPORT_METHOD(resume) {
    if (self.player != nil) {
        [self.player play];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer play];
    }
}

RCT_EXPORT_METHOD(stop) {
    if (self.player != nil) {
        [self.player stop];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer pause];
    }
}

RCT_EXPORT_METHOD(seek:(float)seconds) {
    if (self.player != nil) {
        self.player.currentTime = seconds;
    }
    if (self.avPlayer != nil) {
        [self.avPlayer seekToTime: CMTimeMakeWithSeconds(seconds, 1.0)];
    }
}

#if !TARGET_OS_TV
RCT_EXPORT_METHOD(setSpeaker:(BOOL) on) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if (on) {
        [session setCategory: AVAudioSessionCategoryPlayAndRecord error: nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    } else {
        [session setCategory: AVAudioSessionCategoryPlayback error: nil];
        [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }
    [session setActive:true error:nil];
}
#endif

RCT_EXPORT_METHOD(setMixAudio:(BOOL) on) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    if (on) {
        [session setCategory: AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    } else {
        [session setCategory: AVAudioSessionCategoryPlayback withOptions:0 error:nil];
    }
    [session setActive:true error:nil];
}

RCT_EXPORT_METHOD(setVolume:(float) volume) {
    if (self.player != nil) {
        [self.player setVolume: volume];
    }
    if (self.avPlayer != nil) {
        [self.avPlayer setVolume: volume];
    }
}

RCT_EXPORT_METHOD(setNumberOfLoops:(NSInteger) loopCount) {
    self.loopCount = loopCount;
    if (self.player != nil) {
        [self.player setNumberOfLoops:loopCount];
    }
}

RCT_REMAP_METHOD(getInfo,
                 getInfoWithResolver:(RCTPromiseResolveBlock) resolve
                 rejecter:(RCTPromiseRejectBlock) reject) {
    if (self.player != nil) {
        NSDictionary *data = @{
            @"currentTime": [NSNumber numberWithDouble:[self.player currentTime]],
            @"duration": [NSNumber numberWithDouble:[self.player duration]]
        };
        resolve(data);
        return;
    }
    if (self.avPlayer != nil) {
        CMTime currentTime = [[self.avPlayer currentItem] currentTime];
        CMTime duration = [[[self.avPlayer currentItem] asset] duration];
        NSDictionary *data = @{
            @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(currentTime)],
            @"duration": [NSNumber numberWithFloat:CMTimeGetSeconds(duration)]
        };
        resolve(data);
        return;
    }
    resolve(nil);
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if([player isEqual: self.player2]){
        _player2 = nil;
        return;
    }
    if([player isEqual: self.player3]){
        _player3 = nil;
        return;
    }
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:flag]}];
}

- (void) itemDidFinishPlaying:(NSNotification *) notification {
    [self sendEventWithName:EVENT_FINISHED_PLAYING body:@{@"success": [NSNumber numberWithBool:TRUE]}];
}

- (void) mountSoundFile:(NSString *)name ofType:(NSString *)type {
    if (self.avPlayer) {
        self.avPlayer = nil;
    }
    
    NSURL *soundFileURL = [NSURL fileURLWithPath: name];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    [self.player setDelegate:self];
    [self.player setNumberOfLoops:self.loopCount];
    [self.player prepareToPlay];
    [[AVAudioSession sharedInstance]
     setCategory: AVAudioSessionCategoryPlayback
     error: nil];
    [self sendEventWithName:EVENT_FINISHED_LOADING body:@{@"success": [NSNumber numberWithBool:true]}];
    [self sendEventWithName:EVENT_FINISHED_LOADING_FILE body:@{@"success": [NSNumber numberWithBool:true], @"name": name, @"type": type}];
}

- (void) prepareUrl:(NSString *)url {
    if (self.player) {
        self.player = nil;
    }
    NSURL *soundURL = [NSURL URLWithString:url];
    NSError *playerError;
    NSData *audioData = [[NSData alloc] initWithContentsOfURL:soundURL];
    self.player = [[AVAudioPlayer alloc] initWithData:audioData error:&playerError];
    self.player.delegate = self;
    if(playerError != nil){
        [self sendEventWithName:EVENT_FINISHED_LOADING_URL body:@{@"success": [NSNumber numberWithBool:false]}];
    }else{
        [self sendEventWithName:EVENT_FINISHED_LOADING_URL body:@{@"success": [NSNumber numberWithBool:true]}];
        [self.player prepareToPlay];
    }
}

RCT_EXPORT_MODULE();

@end
