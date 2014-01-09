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

#import <Foundation/Foundation.h>
#import "JSMFileDrone.h"

/**
 * An `JSMFileMonitor` object allows you to watch for changes in a directory. When a change is detected, it can
 * notify a given target by calling a selector.
 *
 * Instances of `JSMFileMonitor` do not list changes made, but simply note that a change has occurred. From there,
 * you can respond to the change as you need to. It should also be noted that a `JSMFileMonitor` object will only
 * monitor the direct children of the given URL; the contents of subfolders are not monitored.
 *
 * If you require a list of changes made to the filesystem, or if you need to monitor an entire directory tree, then you
 * should use an instance of `JSMFileDrone` instead.
 */

@interface JSMFileMonitor : NSObject

///---------------------------------------------
/// @name Instance
///---------------------------------------------

/**
 * Returns a `JSMFileMonitor` object created to watch a location.
 *
 * @param url The location you want to monitor.
 * @return An instance of `JSMFileMonitor` for monitoring the location.
 */

+ (instancetype)monitorWithURL:(NSURL *)url;

///---------------------------------------------
/// @name Location
///---------------------------------------------

/**
 * The location you want to monitor on the device's filesystem.
 */

@property (strong, nonatomic, readonly) NSURL *url;

///---------------------------------------------
/// @name Observing changes
///---------------------------------------------

/**
 * Define the `target` and `selector` for responding to changes detected.
 *
 * @param target The target to notify when changes are detected.
 * @param selector The selector on the reciever's target to call when changes are detected.
 * @return void
 */

- (void)observeChangesWithTarget:(id)target andSelector:(SEL)selector;

/**
 * The target to notify when changes are detected.
 */

@property (nonatomic, readonly) id target;

/**
 * The selector on the reciever's target to call when changes are detected.
 *
 * The defined method should not require any parameters.
 */

@property (nonatomic, readonly) SEL selector;

///---------------------------------------------
/// @name Controlling monitor status
///---------------------------------------------

/**
 * Start monitoring the reciever's `url` for changes.
 *
 * @return Flag indicating whether the monitor was started successfully (true) or not (false).
 */

- (BOOL)start;

/**
 * Stop monitoring the reciever's `url` for changes.
 *
 * @return void
 */

- (void)stop;

@end
