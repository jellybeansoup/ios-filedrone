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

#import "ViewController.h"
#import "FileDrone.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Register a class for the tableview cells
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"TableViewCell"];

    // We'll start the default file drone when this view is loaded.
    // It's pretty easy, and can be done in one line.
    [[JSMFileDrone defaultFileDrone] startSurveillance];

    // And we'll observe the notification so we can update when files change
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(fileDroneDetectedChanges:) name:@"JSMFileDroneFilesChanged" object:nil];

}

- (void)viewWillAppear:(BOOL)animated {

    // Store the fileURLs array locally, so we can make comparisons
    _fileURLs = [JSMFileDrone defaultFileDrone].fileURLs;

    // Ignore me while I show an alert to let you know you can add files using iTunes.
    NSString *message = @"You can either add files using the button in the top right corner, or by using the iTunes file sharing feature.";
    [[[UIAlertView alloc] initWithTitle:@"iTunes File Sharing" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];

}

- (void)dealloc {

    // Lets stop the drone when the view controller is dealloced
    [[JSMFileDrone defaultFileDrone] stopSurveillance];

    // And we'll stop observing the notification
    [NSNotificationCenter.defaultCenter removeObserver:self name:@"JSMFileDroneFilesChanged" object:nil];
    
}

#pragma mark - Add dummy files

- (IBAction)add:(id)sender {

    // We're going to create a random dummy txt file in the documents
    // directory, using a combination of a few random words.

    for( int i=0; i<10; i++ ) {

        NSString *randomString = [self randomString];

        NSURL *fileURL = [[JSMFileDrone defaultFileDrone].directoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt",randomString]];
        if( [[NSFileManager defaultManager] fileExistsAtPath:fileURL.path] ) {
            continue;
        }
        
        NSError *error = nil;
        if( ! [randomString writeToFile:fileURL.path atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
            NSLog(@"Couldn't write to the file: %@", error.localizedFailureReason);
            continue;
        }

        // If we got to here, we can stop
        break;
    }
}

- (NSString *)randomString {
    NSArray *firstWords = @[ @"Cute", @"Sweet", @"Big", @"Small", @"Angry", @"Sad", @"Happy", @"Scary", @"Giant", @"Hungry" ];
    NSString *firstWord = [firstWords objectAtIndex:( rand() % ( 9 - 0 ) + 0 )];
    NSArray *secondWords = @[ @"Green", @"Blue", @"Pink", @"Purple", @"Orange", @"Grey", @"Black", @"White", @"Yellow", @"Red" ];
    NSString *secondWord = [secondWords objectAtIndex:( rand() % ( 9 - 0 ) + 0 )];
    NSArray *thirdWords = @[ @"Rabbit", @"Dog", @"Dinosaur", @"Cat", @"Mouse", @"Bird", @"Ferret", @"Horse", @"Bear", @"Lizard" ];
    NSString *thirdWord = [thirdWords objectAtIndex:( rand() % ( 9 - 0 ) + 0 )];
    return [NSString stringWithFormat:@"%@ %@ %@",firstWord,secondWord,thirdWord];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    // We want one cell for each file in the system
    return _fileURLs.count;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    // Let's display the filename of the file
    NSURL *url = [[JSMFileDrone defaultFileDrone].fileURLs objectAtIndex:indexPath.row];
    cell.textLabel.text = url.lastPathComponent;

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if( editingStyle == UITableViewCellEditingStyleDelete ) {

        NSURL *url = [[JSMFileDrone defaultFileDrone].fileURLs objectAtIndex:indexPath.row];
        NSError *error;
        if( ! [[NSFileManager defaultManager] fileExistsAtPath:url.path] || ! [[NSFileManager defaultManager] removeItemAtURL:url error:&error] ) {
            NSLog(@"Couldn't delete the file: %@", error.localizedFailureReason);
        }

    }
}

#pragma mark - File drone detects changes

- (void)fileDroneDetectedChanges:(NSNotification *)sender {

    // Get the file arrays
    NSArray *fileURLs = [(JSMFileDrone *)sender.object fileURLs];
    NSArray *addedFileURLs = [sender.userInfo objectForKey:kFileDroneNotificationAddedURLs];
    NSArray *removedFileURLs = [sender.userInfo objectForKey:kFileDroneNotificationRemovedURLs];

    // Enumerate through the removed file URLs so we can determine the right index paths
    NSEnumerator *addedEnumerator = addedFileURLs.objectEnumerator;
	NSURL *addedURL;
    NSMutableArray *addedIndexPaths = [NSMutableArray array];
	while( ( addedURL = addedEnumerator.nextObject ) ) {
        [addedIndexPaths addObject:[NSIndexPath indexPathForRow:[fileURLs indexOfObject:addedURL] inSection:0]];
	}

    // Enumerate through the added file URLs so we can determine the right index paths
    NSEnumerator *removedEnumerator = removedFileURLs.objectEnumerator;
	NSURL *removedURL;
    NSMutableArray *removedIndexPaths = [NSMutableArray array];
	while( ( removedURL = removedEnumerator.nextObject ) ) {
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:[_fileURLs indexOfObject:removedURL] inSection:0]];
	}

    // Now update the table view
    [self.tableView beginUpdates];
    _fileURLs = fileURLs;
    if( removedIndexPaths.count > 0 ) {
        [self.tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if( addedIndexPaths.count > 0 ) {
        [self.tableView insertRowsAtIndexPaths:addedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self.tableView endUpdates];

}

@end
