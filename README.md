subjective-lisp
===============
Subjective-Lisp is a Lisp-like interpreter that is built on top of the Objective-C runtime. It currently runs on the iPhone, iPad, and iPod Touch. It is based on Tim Burks' [Nu](http://programming.nu/), but it has been adapted to be more like Paul Graham's [Arc](http://paulgraham.com/arc.html) as it is defined in the [Arc tutorial](http://ycombinator.com/arc/tut.txt), with a few changes.

The main ideas behind Subjective-Lisp are as follows:

* Be able to write code interactively and instantly see the results on your iOS device. Try to eliminate Xcode and the Edit-Compile-Run-Debug cycle, where it becomes more convenient.

* The implementation of the interpreter should be as simple and concise as possible, so that it can be easily understood and modified, giving you complete control of the stack, starting from the low level C/Objective-C code up to the high level code.

* It should be painless to call C/Objective-C code from Lisp, and it should be equally painless to call Lisp code from the C/Objective-C code.

* A simpler implementation of the interpreter is more important than the speed of the interpreter. If speed is important, it is better to rewrite that portion of the code at a lower level (i.e. C/Objective-C), than it is to introduce complexity to the implementation of the interpreter solely for speed.

* Flexibilty.

Subjective-Lisp has S-expressions, but it is not necessarily like other more traditional Lisps. It's intended to be experimental, malleable, and different from what is already out there.

---

At the moment, this xcode project contains a bunch of different third-party code mainly for convenience. I like having lots of code readily available in a giant monolithic ball of wax, since I'm not able to use shared libraries (thanks Apple!)

Here's a list of what's currently included in this xcode project (this list may not be complete):

Snes9x
Nestopia
FFMpeg
ImageMagick
Chipmunk
Cocos2d
Curl
PCRE
evhtp
libevent
libtiff
libpng
libjpeg
libfftw
djvulibre
CocoaHTTPServer

When you run this program on your iOS device, it will download code from http://interactiveios.org/symbols.json and run it. The symbols.json file is basically a dictionary of symbols encoded as a JSON object (the interactive-ios repository encoded as JSON).

At the moment, what you are presented with is a table view. You are able to browse your "Documents" directory, and you can view various file types, ".nes" files will get run by the NES emulator, ".smc" files will get run by the SNES emulator, ".m4v" files will get displayed by the FFMpeg wrapper, etc. There is a bug in the NES emulator that was introduced with the new version of Xccode which causes compilation to partially fail, so not all games work at the moment, until I am able to track the bug down.

For more information, visit [subjectivelisp.org](http://subjectivelisp.org).

Arthur Choung
arthur_choung@me.com

