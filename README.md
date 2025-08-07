# iOSPointMapper
iOS application that collects standardized information for accurate mapping of outdoor sidewalks, frontages and indoor spaces

## To run the application

1. Clone the repository

2. Inside the [Frameworks](Frameworks/) folder, add the required frameworks

- OpenCV: https://opencv.org/releases/\
Download OpenCV – 4.10.0 "iOS Pack".
Unzip and add the XCFramework file to [Frameworks](Frameworks/)


Note: While adding the frameworks, Xcode may not recognize the framework. In that case, you can add the framework manually by following the steps below:
- Remove the existing framework reference from the Xcode project navigator
- Drag and drop the framework file to the Xcode project navigator
- In the dialog that appears, make sure the "Copy items if needed" checkbox is checked and the target is selected
- Click Finish
- Go to the project settings -> General -> Frameworks, Libraries, and Embedded Content
- Change the Embed status of the framework to "Embed & Sign"
- Clean the project and build again

3. Open the `IOSAccessAssessment.xcodeproj` file in Xcode

4. Select the target device (iOS device or simulator) and run the application

## Other Resources

1. Machine Learning\
[Main Repository](https://github.com/himanshunaidu/ML_Pipeline_iOSPointMapper): The machine learning repository used to perform ML model inference, conversion and additional analysis.\
Currently, the repository does not support training of models, and this is done in separate repositories:
- [EdgeNets](https://github.com/sacmehta/EdgeNets): For ESPNetv2
- [BiSeNet](https://github.com/himanshunaidu/ML_Pipeline_iOSPointMapper): (Fork) For BiSeNet and BiSeNetV2

2. Data Collection\
[iOSPointMapperDataCollector](https://github.com/himanshunaidu/iOSPointMapperDataCollector): (Fork) The iOS app used to collect datasets for the project. \
[StrayVisualizer](https://github.com/himanshunaidu/StrayVisualizer): The repository used to process the collected data and visualize it.


## Interest Form

If you are interested in being a part of the project, you can fill this form and we can get back to you ASAP: \
[Interest Form](https://docs.google.com/forms/d/e/1FAIpQLSccLrBbDRPBinN1iyetmjndUz1LcftNWXvH3Y_Xets0RR-R4g/viewform?usp=dialog)
