//
//  RingModulatorAudioUnit.m
//  RingModulator
//
//  Created by Chris Adamson on 4/18/17.
//  Provided under Creative Commons Zero license - https://creativecommons.org/publicdomain/zero/1.0/
//

#import "RingModulatorAudioUnit.h"

#import <AVFoundation/AVFoundation.h>

// Define parameter addresses.
const AUParameterAddress frequencyParam = 0;

@interface RingModulatorAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
// need these for actual filtering
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;


@end


@implementation RingModulatorAudioUnit
@synthesize parameterTree = _parameterTree;

AUAudioUnitBus *_inputBus; // was BufferedInputBus in sample code
AudioStreamBasicDescription asbd; // local copy of the asbd that block can capture

UInt64 totalFrames = 0;
AUValue frequency = 22;
AudioBufferList renderABL;


- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) {
        return nil;
    }
    
    
    // @invalidname: Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    
    asbd = *defaultFormat.streamDescription;
    
    NSLog (@"^^^^ defaultFormat.streamDescription:\n"\
           "mBitsPerChannel: %u,\n"\
           "mBytesPerFrame: %u,\n"\
           "mBytesPerPacket: %u,\n"\
           "mChannelsPerFrame: %u,\n"\
           "mFormatID: %u, \n"\
           "mFormatFlags: 0x%x,\n"\
           "mFramesPerPacket: %u,\n"\
           "mSampleRate: %f\n",
           (unsigned int) asbd.mBitsPerChannel,
           (unsigned int) asbd.mBytesPerFrame,
           (unsigned int) asbd.mBytesPerPacket,
           (unsigned int) asbd.mChannelsPerFrame,
           (unsigned int) asbd.mFormatID,
           (unsigned int) asbd.mFormatFlags,
           (unsigned int) asbd.mFramesPerPacket,
           asbd.mSampleRate
           );
    NSLog (@"This %@ kAudioFormatFlagsNativeFloatPacked (%u)",
           asbd.mFormatFlags == kAudioFormatFlagsNativeFloatPacked ? @"is" : @"is not",
           kAudioFormatFlagsNativeFloatPacked);
    
   
    // Create parameter objects.
    AUParameter *param1 = [AUParameterTree createParameterWithIdentifier:@"frequency" name:@"Frequency" address:frequencyParam min:15 max:40 unit:kAudioUnitParameterUnit_Hertz unitName:nil flags:0 valueStrings:nil dependentParameters:nil];
    
    // Initialize the parameter values.
    param1.value = 22;
    
    // Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:@[ param1 ]];
    
    // Create the input and output busses (AUAudioUnitBus).
    // @invalidname
    _inputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    
    // Create the input and output bus arrays (AUAudioUnitBusArray).
    // @invalidname
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];

    
    // implementorValueObserver is called when a parameter changes value.
    _parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        switch (param.address) {
            case frequencyParam:
                frequency = value;
                break;
            default:
                break;
        }
    };
    
    // implementorValueProvider is called when the value needs to be refreshed.
    _parameterTree.implementorValueProvider = ^(AUParameter *param) {
        switch (param.address) {
            case frequencyParam:
                return frequency; // TODO: is this capturing self?
            default:
                return (AUValue) 0.0;
        }
    };
    
    
    // A function to provide string representations of parameter values.
    _parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
        AUValue value = valuePtr == nil ? param.value : *valuePtr;
        
        switch (param.address) {
            case frequencyParam:
                return [NSString stringWithFormat:@"%.0f", value];
            default:
                return @"?";
        }
    };
    
    self.maximumFramesToRender = 512;
    
    return self;
}

#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
    NSLog (@"MyAudioUnit inputBusses called");
    return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
    NSLog (@"MyAudioUnit outputBusses called");
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    if (![super allocateRenderResourcesAndReturnError:outError]) {
        return NO;
    }
    
    // Validate that the bus formats are compatible.
    // Allocate your resources.
    renderABL.mNumberBuffers = 2; // this is actually needed
    
    totalFrames = 0;
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    // Deallocate your resources.
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock {
    // Capture in locals to avoid Obj-C member lookups. If "self" is captured in render, we're doing it wrong. See sample code.
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp, AVAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList *outputData, const AURenderEvent *realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
        // Do event handling and signal processing here.
        
        // cheat: use logged asbd's format from above (float + packed + noninterleaved)
        if (asbd.mFormatID != kAudioFormatLinearPCM || asbd.mFormatFlags != 0x29 || asbd.mChannelsPerFrame != 2) {
            return -999;
        }
        
        // pull in samples to filter
        pullInputBlock(actionFlags, timestamp, frameCount, 0, &renderABL);
        
        size_t sampleSize = sizeof(Float32);
        for (int frame = 0; frame < frameCount; frame++) {
            totalFrames++;
            
            for (int renderBuf = 0; renderBuf < renderABL.mNumberBuffers; renderBuf++) {
                Float32 *sample = renderABL.mBuffers[renderBuf].mData + (frame * asbd.mBytesPerFrame);
                // apply modulation
                // ?? - should this take the absf() of the sinf(), so we don't invert waves?
                Float32 time = totalFrames / asbd.mSampleRate;
                *sample = *sample * sinf(M_PI * 2 * time * frequency);
                
                memcpy(outputData->mBuffers[renderBuf].mData + (frame * asbd.mBytesPerFrame),
                       sample,
                       sampleSize);
            }
        }
        
        return noErr;
    };
}

@end

