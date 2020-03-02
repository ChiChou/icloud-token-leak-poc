SRC=src/poc.m src/Instruments.m
RPATH=/Applications/Xcode.app/Contents/Developer/Library/Frameworks, \
	/Applications/Xcode.app/Contents/Developer/Library/PrivateFrameworks, \
	/Applications/Xcode.app/Contents/SharedFrameworks, \
	/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Frameworks
LDFLAGS=-framework Foundation -limobiledevice \
	-L/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Frameworks \
	-Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Library/Frameworks \
	-Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Developer/Library/PrivateFrameworks \
	-Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/SharedFrameworks \
	-Xlinker -rpath -Xlinker /Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Frameworks \
	-F/Applications/Xcode.app/Contents/Applications/Instruments.app/Contents/Frameworks/ \
	-F/Applications/Xcode.app/Contents/SharedFrameworks/ \
	-framework InstrumentsPlugIn \
	-framework DVTFoundation 

all: prepare $(SRC)
	cc $(SRC) $(LDFLAGS) -o bin/poc

prepare:
	mkdir -p bin

format:
	clang-format -i $(SRC)

run: all
	./bin/poc

demo: all
	./bin/poc
	python3 extract.py