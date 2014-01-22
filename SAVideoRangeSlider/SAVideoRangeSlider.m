//
//  SAVideoRangeSlider.m
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2013 Andrei Solovjev - http://solovjev.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SAVideoRangeSlider.h"


// How many points should the left thumb be virtually extended to the left?
#define TOUCH_PAN_LEFT_MAX_DIFF -10

// How many points should the left thumb be virtually extended to the right?
#define TOUCH_PAN_RIGHT_MAX_DIFF 30

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *centerView;
@property (nonatomic, strong) NSURL *videoUrl;
@property (nonatomic, strong) SASliderLeft *leftThumb;
@property (nonatomic, strong) SASliderRight *rightThumb;
@property (nonatomic) CGFloat frame_width;
@property (nonatomic) Float64 durationSeconds;
@property (nonatomic, strong) SAResizibleBubble *popoverBubble;

/**
 * Variable which determines what gesture type has to be executed. Is calculated at the beginning of the UIPanRecognizer. -1 = invalid, 0 = left, 1 = right, 2 = center.
 */
@property (nonatomic)         int handlePanGestureType;

@end

@implementation SAVideoRangeSlider


#define SLIDER_BORDERS_SIZE 3.0f
#define BG_VIEW_BORDERS_SIZE 3.0f


- (id)initWithFrame:(CGRect)frame videoUrl:(NSURL *)videoUrl{

    self = [super initWithFrame:frame];
    if (self) {

        _frame_width = frame.size.width;

        int thumbWidth = ceil(frame.size.width*0.05);

        _bgView = [[UIControl alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor grayColor].CGColor;
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        [self addSubview:_bgView];

        _videoUrl = videoUrl;


        _topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE)];
        _topBorder.backgroundColor = [UIColor colorWithRed: 0.996 green: 0.951 blue: 0.502 alpha: 1];
        [self addSubview:_topBorder];


        _bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE)];
        _bottomBorder.backgroundColor = [UIColor colorWithRed: 0.992 green: 0.902 blue: 0.004 alpha: 1];
        [self addSubview:_bottomBorder];


        _leftThumb = [[SASliderLeft alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        _leftThumb.contentMode = UIViewContentModeLeft;
        _leftThumb.userInteractionEnabled = YES;
        _leftThumb.clipsToBounds = YES;
        _leftThumb.backgroundColor = [UIColor clearColor];
        _leftThumb.layer.borderWidth = 0;
        [self addSubview:_leftThumb];

        _rightThumb = [[SASliderRight alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];

        _rightThumb.contentMode = UIViewContentModeRight;
        _rightThumb.userInteractionEnabled = YES;
        _rightThumb.clipsToBounds = YES;
        _rightThumb.backgroundColor = [UIColor clearColor];
        [self addSubview:_rightThumb];

        _rightPosition = frame.size.width;
        _leftPosition = 0;

        _centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _centerView.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerView];

        _popoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, -50, 100, 50)];
        _popoverBubble.alpha = 0;
        _popoverBubble.backgroundColor = [UIColor clearColor];
        [self addSubview:_popoverBubble];


        _bubbleText = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, _popoverBubble.frame.size.width - 20, _popoverBubble.frame.size.height)];
        _bubbleText.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:10];
        _bubbleText.backgroundColor = [UIColor clearColor];
        _bubbleText.textColor = [UIColor blackColor];
        _bubbleText.textAlignment = NSTextAlignmentCenter;

        [_popoverBubble addSubview:_bubbleText];

        UIPanGestureRecognizer *centerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [self addGestureRecognizer:centerPan];

        [self getMovieFrame];

        _minGap = 0.25;
    }

    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


-(void)setPopoverBubbleSize: (CGFloat) width height:(CGFloat)height{
    if (self.enablePopover) {
        CGRect currentFrame = _popoverBubble.frame;
        currentFrame.size.width = width;
        currentFrame.size.height = height;
        currentFrame.origin.y = -height;
        _popoverBubble.frame = currentFrame;

        currentFrame.origin.x = 0;
        currentFrame.origin.y = 0;
        _bubbleText.frame = _popoverBubble.frame;
    }
}


-(void)setMaxGap:(NSInteger)maxGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*maxGap/_durationSeconds;
    _maxGap = maxGap;
}

-(void)setMinGap:(NSInteger)minGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*minGap/_durationSeconds;
    _minGap = minGap;
}


- (void)delegateNotification
{
    if ([_delegate respondsToSelector:@selector(videoRange:didChangeLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didChangeLeftPosition:self.leftPosition rightPosition:self.rightPosition];
    }

}


#pragma mark - Gestures

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [gesture locationInView:self];

        int diffLeft = location.x - _leftThumb.frame.origin.x;
        int diffRight = _rightThumb.frame.origin.x + _rightThumb.frame.size.width - location.x;
        int diffBetween = abs(self.rightThumb.frame.origin.x - (self.leftThumb.frame.origin.x + self.leftThumb.frame.size.width*2));

        if(diffBetween <= abs(TOUCH_PAN_LEFT_MAX_DIFF) + TOUCH_PAN_RIGHT_MAX_DIFF) {
            // both virtual thumb extensions are overlapping!
            // determine if the user touched left or right of the thumbs and control the coresponding one.

            // ALTERNATIVE: Always allow to control the thumbs by touching left and right of them.

            if(diffLeft < 0) {
                self.handlePanGestureType = 0;
            } else if(diffRight < 0) {
                self.handlePanGestureType = 1;
            }
        } else {
            // make the two thumbs virtually larger, so they can be used without hitting them 100% perfectly
            if(diffLeft >= TOUCH_PAN_LEFT_MAX_DIFF && diffLeft <= TOUCH_PAN_RIGHT_MAX_DIFF) {
                self.handlePanGestureType = 0;
            } else if(diffRight >= TOUCH_PAN_LEFT_MAX_DIFF && diffRight <= TOUCH_PAN_RIGHT_MAX_DIFF) {
                self.handlePanGestureType = 1;
            } else if (diffLeft > TOUCH_PAN_RIGHT_MAX_DIFF && diffRight > TOUCH_PAN_RIGHT_MAX_DIFF ) {
                self.handlePanGestureType = 2;
            } else {
                self.handlePanGestureType = -1; // invalid
            }
        }
    }

    if(self.handlePanGestureType == 0) {
        [self handleLeftPan:gesture];
    } else if(self.handlePanGestureType == 1) {
        [self handleRightPan:gesture];
    } else if(self.handlePanGestureType == 2) {
        [self handleCenterPan:gesture];
    }
}

- (void)handleLeftPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {

        CGPoint translation = [gesture translationInView:self];

        _leftPosition += translation.x;
        if (_leftPosition < 0) {
            _leftPosition = 0;
        }

        if (
            (_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))
            ){
            _leftPosition -= translation.x;
        }

        [gesture setTranslation:CGPointZero inView:self];

        [self setNeedsLayout];

        [self delegateNotification];

    }

    if(self.enablePopover) {
        _popoverBubble.alpha = 1;
        [self setTimeLabel];
        if (gesture.state == UIGestureRecognizerStateEnded){
            [self hideBubble:_popoverBubble];
        }
    }
}


- (void)handleRightPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {


        CGPoint translation = [gesture translationInView:self];
        _rightPosition += translation.x;
        if (_rightPosition < 0) {
            _rightPosition = 0;
        }

        if (_rightPosition > _frame_width){
            _rightPosition = _frame_width;
        }

        if (_rightPosition-_leftPosition <= 0){
            _rightPosition -= translation.x;
        }

        if ((_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))){
            _rightPosition -= translation.x;
        }

        [gesture setTranslation:CGPointZero inView:self];

        [self setNeedsLayout];

        [self delegateNotification];

    }

    if(self.enablePopover) {
        _popoverBubble.alpha = 1;
        [self setTimeLabel];
        if (gesture.state == UIGestureRecognizerStateEnded){
            [self hideBubble:_popoverBubble];
        }
    }
}


- (void)handleCenterPan:(UIPanGestureRecognizer *)gesture
{

    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {

        CGPoint translation = [gesture translationInView:self];

        _leftPosition += translation.x;
        _rightPosition += translation.x;

        if (_rightPosition > _frame_width || _leftPosition < 0){
            _leftPosition -= translation.x;
            _rightPosition -= translation.x;
        }


        [gesture setTranslation:CGPointZero inView:self];

        [self setNeedsLayout];

        [self delegateNotification];

    }

    if(self.enablePopover) {
        _popoverBubble.alpha = 1;
        [self setTimeLabel];
        if (gesture.state == UIGestureRecognizerStateEnded){
            [self hideBubble:_popoverBubble];
        }
    }

}


- (void)layoutSubviews
{
    CGFloat inset = _leftThumb.frame.size.width / 2;

    _leftThumb.center = CGPointMake(_leftPosition+inset, _leftThumb.frame.size.height/2);

    _rightThumb.center = CGPointMake(_rightPosition-inset, _rightThumb.frame.size.height/2);

    _topBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, 0, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);

    _bottomBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _bgView.frame.size.height-SLIDER_BORDERS_SIZE, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);


    _centerView.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _centerView.frame.origin.y, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width - _leftThumb.frame.size.width, _centerView.frame.size.height);

    if (self.enablePopover) {
        CGRect frame = _popoverBubble.frame;
        frame.origin.x = _centerView.frame.origin.x+_centerView.frame.size.width/2-frame.size.width/2;
        _popoverBubble.frame = frame;
    }
}




#pragma mark - Video

-(void)getMovieFrame{

    AVAsset *myAsset = [[AVURLAsset alloc] initWithURL:_videoUrl options:nil];
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];

    if ([self isRetina]){
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*2, _bgView.frame.size.height*2);
    } else {
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width, _bgView.frame.size.height);
    }

    int picWidth = 49;

    // First image
    NSError *error;
    CMTime actualTime;
    CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:&error];
    if (halfWayImage != NULL) {
        UIImage *videoScreen;
        if ([self isRetina]){
            videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:2.0 orientation:UIImageOrientationUp];
        } else {
            videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage];
        }
        UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
        [_bgView addSubview:tmp];
        picWidth = tmp.frame.size.width;
        CGImageRelease(halfWayImage);
    }


    _durationSeconds = CMTimeGetSeconds([myAsset duration]);

    int picsCnt = ceil(_bgView.frame.size.width / picWidth);

    NSMutableArray *allTimes = [[NSMutableArray alloc] init];

    int time4Pic = 0;

    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
        // Bug iOS7 - generateCGImagesAsynchronouslyForTimes

        for (int i=1, ii=1; i<picsCnt; i++){
            time4Pic = i*picWidth;

            CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);

            [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];


            CGImageRef halfWayImage = [self.imageGenerator copyCGImageAtTime:timeFrame actualTime:&actualTime error:&error];

            UIImage *videoScreen;
            if ([self isRetina]){
                videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage scale:2.0 orientation:UIImageOrientationUp];
            } else {
                videoScreen = [[UIImage alloc] initWithCGImage:halfWayImage];
            }



            UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];

            int all = (ii+1)*tmp.frame.size.width;


            CGRect currentFrame = tmp.frame;
            currentFrame.origin.x = ii*currentFrame.size.width;
            if (all > _bgView.frame.size.width){
                int delta = all - _bgView.frame.size.width;
                currentFrame.size.width -= delta;
            }
            tmp.frame = currentFrame;
            ii++;

            dispatch_async(dispatch_get_main_queue(), ^{
                [_bgView addSubview:tmp];
            });




            CGImageRelease(halfWayImage);

        }


        return;
    }

    for (int i=1; i<picsCnt; i++){
        time4Pic = i*picWidth;

        CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);

        [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];
    }

    NSArray *times = allTimes;

    __block int i = 1;

    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times
                                              completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime,
                                                                  AVAssetImageGeneratorResult result, NSError *error) {

                                                  if (result == AVAssetImageGeneratorSucceeded) {


                                                      UIImage *videoScreen;
                                                      if ([self isRetina]){
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image scale:2.0 orientation:UIImageOrientationUp];
                                                      } else {
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image];
                                                      }


                                                      UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];

                                                      int all = (i+1)*tmp.frame.size.width;


                                                      CGRect currentFrame = tmp.frame;
                                                      currentFrame.origin.x = i*currentFrame.size.width;
                                                      if (all > _bgView.frame.size.width){
                                                          int delta = all - _bgView.frame.size.width;
                                                          currentFrame.size.width -= delta;
                                                      }
                                                      tmp.frame = currentFrame;
                                                      i++;

                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [_bgView addSubview:tmp];
                                                      });

                                                  }

                                                  if (result == AVAssetImageGeneratorFailed) {
                                                      NSLog(@"Failed with error: %@", [error localizedDescription]);
                                                  }
                                                  if (result == AVAssetImageGeneratorCancelled) {
                                                      NSLog(@"Canceled");
                                                  }
                                              }];
}




#pragma mark - Properties

- (CGFloat)leftPosition
{
    return (_leftPosition) / (_bgView.frame.size.width - BG_VIEW_BORDERS_SIZE*2)  * _durationSeconds;
}


- (CGFloat)rightPosition
{
    return (_rightPosition - _rightThumb.frame.size.width - _leftThumb.frame.size.width) / (_bgView.frame.size.width - BG_VIEW_BORDERS_SIZE*2)  * _durationSeconds;
}




#pragma mark - Bubble

- (void)hideBubble:(UIView *)popover
{
    [UIView animateWithDuration:0.4
                          delay:0
                        options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {

                         _popoverBubble.alpha = 0;
                     }
                     completion:nil];

    if ([_delegate respondsToSelector:@selector(videoRange:didGestureStateEndedLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didGestureStateEndedLeftPosition:self.leftPosition rightPosition:self.rightPosition];
        
    }
}


-(void) setTimeLabel{
    self.bubbleText.text = [self trimIntervalStr];
    NSLog(@"[self trimIntervalStr]=%@", [self trimIntervalStr]);
    //NSLog([self timeDuration]);
}


-(NSString *)trimDurationStr{
    int delta = floor(self.rightPosition - self.leftPosition);
    return [NSString stringWithFormat:@"%d", delta];
}


-(NSString *)trimIntervalStr{
    
    NSString *from = [self timeToStr:self.leftPosition];
    NSString *to = [self timeToStr:self.rightPosition];
    return [NSString stringWithFormat:@"%@ - %@", from, to];
}




#pragma mark - Helpers

- (NSString *)timeToStr:(CGFloat)time
{
    // time - seconds
    NSInteger min = floor(time / 60);
    NSInteger sec = floor(time - min * 60);
    NSString *minStr = [NSString stringWithFormat:min >= 10 ? @"%i" : @"0%i", min];
    NSString *secStr = [NSString stringWithFormat:sec >= 10 ? @"%i" : @"0%i", sec];
    return [NSString stringWithFormat:@"%@:%@", minStr, secStr];
}


-(BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
            
            ([UIScreen mainScreen].scale == 2.0));
}


@end
