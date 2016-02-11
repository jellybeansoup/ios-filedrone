#FileDrone

A simple mechanism that allows you to track changes to your app's files. Each instance of the FileDrone will watch a directory for changes, provide a list of files in that directory, and will post a notification with the changes when they occur. It's *super* lightweight, and makes it much easier to implement an app that builds on the file system, such as ones that you might include in the Documents directory.

##Installation

There are a couple of ways to include FileDrone in your Xcode project.

###Subproject

This method is demonstrated in the included example project (example/FileDroneExample.xcodeproj).

1. Drag the `FileDrone.xcodeproj` file into your Project Navigator (⌘1) from the Finder. This should add FileDrone as a subproject of your own project (denoted by the fact that it appears as in a rectangle and you should be able to browse the project structure).

2. In your Project's target, under the Build Phases tab, add `libFileDrone.a` under 'Link Binary with Libraries'.

3. While you're in the Build Phases tab, add `libFileDrone.a` under 'Target Dependencies'.

4. Under the Build Settings tab of you Project's target, do a search for 'Header Search Paths'. Add the path to the `/src/FileDrone/` folder of the FileDrone project. This should look something like `"$(SRCROOT)/../src/FileDrone/"`, replacing the `..` with the relative path from your project to the FileDrone project.

5. Build your project (⌘B). All going well, you should get a 'Build Succeeded' notification. This signifies that you're ready to implement FileDrone in your project.

###CocoaPods

FileDrone can be installed *very* easily if you use [CocoaPods](http://cocoapods.org) with your projects. The podspec is included in the Github repository, and is also available through [cocoapods.org](http://cocoapods.org/?q=FileDrone).

Simply add the project to your `Podfile` by adding the line:

```ruby 
pod 'FileDrone'
```

And run `pod update` in terminal to update the pods you have included in your project.

You can also specify a version to include, such as 0.1.0:

```ruby
pod 'FileDrone', '0.1.0'
```

For more information on how to add projects using CocoaPods, read [their documentation on Podfiles](http://docs.cocoapods.org/podfile.html).

##Implementing FileDrone

To use automatic surveillance on the Documents directory, you can use the default file drone, and simply start and stop it in your App Delegate.

At the top of the App Delegate's implemention file, include FileDrone:

```objc
#import "FileDrone.h"
```

In `application:didFinishLaunchingWithOptions:`, start the default file drone like so:

```objc
[[JSMFileDrone defaultFileDrone] startSurveillance];
```

The file drone will start watching the directory's contents for changes and will post a `JSMFileDroneFilesChanged` notification when it detects changes. It will also begin observing system notifications and pause itself while your app is in the background, or is inactive, and will stop completely when the app is terminated.

For more details on implementing FileDrone, read the documentation and check out the included FileDroneExample project.

##Released under the BSD License

Copyright © 2013 Daniel Farrelly

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

*	Redistributions of source code must retain the above copyright notice, this list
	of conditions and the following disclaimer.
*	Redistributions in binary form must reproduce the above copyright notice, this
	list of conditions and the following disclaimer in the documentation and/or
	other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
