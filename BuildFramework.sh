
# set the output folder
FRAMEWORK_OUTPUT_FOLDER="Build/Framework Products"

# create the output folder
mkdir -p "${FRAMEWORK_OUTPUT_FOLDER}"

# build the sdk for ios
xcodebuild archive \
 -archivePath "${FRAMEWORK_OUTPUT_FOLDER}/TuneURL-iphoneos.xcarchive" \
 -workspace TuneURL.xcworkspace \
 -scheme "TuneURL (SDK)" \
 -sdk iphoneos

# build the sdk for the simulator
xcodebuild archive \
 -archivePath "${FRAMEWORK_OUTPUT_FOLDER}/TuneURL-iphonesimulator.xcarchive" \
 -workspace TuneURL.xcworkspace \
 -scheme "TuneURL (SDK)" \
 -sdk iphonesimulator

# build the xcframework
xcodebuild -create-xcframework \
 -framework "${FRAMEWORK_OUTPUT_FOLDER}/TuneURL-iphoneos.xcarchive/Products/Library/Frameworks/TuneURL.framework" \
 -framework "${FRAMEWORK_OUTPUT_FOLDER}/TuneURL-iphonesimulator.xcarchive/Products/Library/Frameworks/TuneURL.framework" \
 -output "${FRAMEWORK_OUTPUT_FOLDER}/TuneURL.xcframework"
