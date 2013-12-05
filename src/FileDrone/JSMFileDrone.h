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

#define kFileDroneNotificationDirectoryURL @"kFileDroneNotificationDirectoryURL"
#define kFileDroneNotificationAddedURLs @"kFileDroneNotificationAddedURLs"
#define kFileDroneNotificationRemovedURLs @"kFileDroneNotificationRemovedURLs"

/**
 * An `JSMFileDrone` object lets you track files in a directory, optionally sending a notification via
 * `NSNotificationCenter` when files are added or removed. The changes are reported as an arrays containing files added to
 * the directory, and files removed from the directory.
 *
 * A file drone instance can be used to either manually or automatically check for changes to files. To manually check for
 * changes, an `JSMFileDrone` object provides `refresh`, which will update the internal `NSURL` collections with the changes
 * without posting a notification (if you're allergic to that kind of thing). Automatic surveillance can be started and
 * stopped with `startSurveillance` and `stopSurveillance` respectively, and will both update the `NSURL` collections, and
 * post the changes via the `JSMFileDroneFilesChanged` notification so you can easily update your UI.
 *
 * When using automatic surveillance, `JSMFileDrone` automatically observes notification about your applications state,
 * pausing itself when the app goes into the background or becomes inactive, and will resume automatically when it returns to
 * the foreground, or an active state.
 */

@interface JSMFileDrone : NSObject

///---------------------------------------------
/// @name Creating a FileDrone
///---------------------------------------------

/**
 * Returns a `JSMFileDrone` object created to watch the Documents directory for changes.
 *
 * If you plan to watch a directory other than the default Documents directory, you should create another instance using
 * `fileDroneForDirectoryURL:` and provide an `NSURL` object representing a directory to watch instead.
 *
 * @return The default `JSMFileDrone` instance.
 */

+ (instancetype)defaultFileDrone;

/**
 * Returns a `JSMFileDrone` object created to watch the given directory for changes.
 *
 * @param directoryURL The directory you want to watch.
 * @return An instance of `JSMFileDrone` for the given directory.
 */

+ (instancetype)fileDroneForDirectoryURL:(NSURL *)directoryURL;

///---------------------------------------------
/// @name Directory
///---------------------------------------------

/**
 * The directory to watch with this file drone.
 */

@property (strong, nonatomic) NSURL *directoryURL;

///---------------------------------------------
/// @name Files
///---------------------------------------------

/**
 * Array containing `NSURL` objects for all files within the directory.
 */

@property (strong, nonatomic, readonly) NSArray *fileURLs;

/**
 * Array containing `NSURL` objects for files added to the directory.
 *
 * The contents of this array only reflects the new files detected during the last check.
 */

@property (strong, nonatomic, readonly) NSArray *addedFileURLs;

/**
 * Array containing `NSURL` objects for files removed from the directory.
 *
 * The contents of this array only reflects the removed files detected during the last check.
 */

@property (strong, nonatomic, readonly) NSArray *removedFileURLs;

///---------------------------------------------
/// @name Manual surveillance
///---------------------------------------------

/**
 * Check the documents directory for any file changes.
 *
 * @return void
 */

- (void)refresh;

///---------------------------------------------
/// @name Automatic surveillance
///---------------------------------------------

/**
 * Flag indicating whether the directory is currently under surveillance.
 */

@property (nonatomic, readonly) BOOL isSurveilling;

/**
 * Start checking the directory for changes in the background.
 *
 * This method will automatically subscribe to notifications about the application's background status so the drone gets
 * paused while the app is in the background, and will resume when the app returns to the foreground.
 *
 * @return void
 */

- (void)startSurveillance;

/**
 * Stop checking the directory for changes in the background.
 *
 * This method will unsubscribes from notifications about the application's background status. This effectively means the
 * drone will *not* resume checking the directory for changes automatically resume when the application enters the foreground.
 *
 * @return void
 */

- (void)stopSurveillance;

@end
