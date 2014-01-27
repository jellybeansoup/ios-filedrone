//
// Copyright © 2013 Daniel Farrelly
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// *	Redistributions of source code must retain the above copyright notice, this list
//		of conditions and the following disclaimer.
// *	Redistributions in binary form must reproduce the above copyright notice, this
//		list of conditions and the following disclaimer in the documentation and/or
//		other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "JSMFileMonitor.h"
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>

@interface JSMFileMonitor ()

@property (nonatomic) int dirFD;

@property (nonatomic) int kq;

@property (nonatomic) CFFileDescriptorRef dirkqRef;

@end

@implementation JSMFileMonitor

@synthesize url = _url;
@synthesize target = _target;
@synthesize selector = _selector;

#pragma mark - Instance

+ (instancetype)monitorWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url];
}

- (instancetype)initWithURL:(NSURL *)url {
    if( ( self = [super init] ) ) {
        _url = url;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

#pragma mark - Observing changes

- (void)observeChangesWithTarget:(id)target andSelector:(SEL)selector {
    _target = target;
    _selector = selector;
}

#pragma mark - Controlling monitor status

static void fileDroneDescriptorCallBack(CFFileDescriptorRef kqRef, CFOptionFlags callBackTypes, void *info) {
    JSMFileMonitor *monitor = (__bridge JSMFileMonitor *)info;
    if( ! [monitor isKindOfClass:[JSMFileMonitor class]] || kqRef != monitor.dirkqRef || callBackTypes != kCFFileDescriptorReadCallBack ) {
        return;
    }
    // Apparently this descriptor is no good
    if( monitor.kq == -1 ) {
        return;
    }
    // Check the event count
    struct kevent event;
    struct timespec timeout = {0, 0};
    int eventCount = kevent(monitor.kq, NULL, 0, &event, 1, &timeout);
    if( eventCount < 0 && eventCount >= 2 ) {
        return;
    }
    // Refresh the file lists
    if( monitor.target != nil && monitor.selector != nil && [monitor.target respondsToSelector:monitor.selector] ) {
        IMP method = [monitor.target methodForSelector:monitor.selector];
        void (*performSelector)(id, SEL) = (void *)method;
        performSelector(monitor.target, monitor.selector);
    }
    // Reenable the callback
    CFFileDescriptorEnableCallBacks(monitor.dirkqRef, kCFFileDescriptorReadCallBack);
}

- (BOOL)start {
    // Double initializing is not going to work...
    if( _dirkqRef != nil && _dirFD >= 0 && _kq >= 0 ) {
        return NO;
    }
    // Open the directory we're going to watch
    if ( ( _dirFD = open(_url.fileSystemRepresentation, O_EVTONLY) ) >= 0 ) {
        // Create a kqueue for our event messages...
        if( ( _kq = kqueue() ) >= 0 ) {
            // Set up the event
            struct kevent eventToAdd;
            eventToAdd.ident  = _dirFD;
            eventToAdd.filter = EVFILT_VNODE;
            eventToAdd.flags  = EV_ADD | EV_CLEAR;
            eventToAdd.fflags = NOTE_WRITE;
            eventToAdd.data   = 0;
            eventToAdd.udata  = NULL;
            if( kevent( _kq, &eventToAdd, 1, NULL, 0, NULL ) == 0 ) {
                // Prep the context
                CFFileDescriptorContext context = { 0, (__bridge void *)(self), NULL, NULL, NULL };
                // Passing true in the third argument so CFFileDescriptorInvalidate will close _kq.
                CFRunLoopSourceRef rls;
                if( ( _dirkqRef = CFFileDescriptorCreate(NULL, _kq, true, fileDroneDescriptorCallBack, &context) ) != NULL ) {
                    if( ( rls = CFFileDescriptorCreateRunLoopSource(NULL, _dirkqRef, 0) ) != NULL) {
                        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
                        CFRelease(rls);
                        CFFileDescriptorEnableCallBacks(_dirkqRef, kCFFileDescriptorReadCallBack);
                        // If everything worked, return early and bypass shutting things down
                        return YES;
                    }
                    // Couldn't create a runloop source, invalidate and release the CFFileDescriptorRef
                    CFFileDescriptorInvalidate(_dirkqRef);
                    CFRelease(_dirkqRef);
                    _dirkqRef = nil;
                }
            }
        }
        // File handle is open, but something failed, close the handle...
        close(_dirFD);
        _dirFD = -1;
    }
    // Default to no
    return NO;
}

- (void)stop {
	if( _dirkqRef != nil ) {
		CFFileDescriptorInvalidate(_dirkqRef);
		CFRelease(_dirkqRef);
		_dirkqRef = nil;
		_kq = -1;
	}
	if( _dirFD != -1 ) {
		close(_dirFD);
		_dirFD = -1;
	}
}

@end
