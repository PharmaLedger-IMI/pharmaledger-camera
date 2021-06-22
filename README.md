# PharmaLedger Camera

This readme is mainly meant as internal TrueMed documentation for managing the PharmaLedger iOS camera framework.

## Contents

- Camera Sample (Swift project that implements the Camera Framework)
- pharmaledger_flutterdemo (Flutter application that uses the Camera Framework to access the native camera)
- PharmaLedger Camera (native iOS camera Framework)

## Building Documentation

Currently documentation is generated using [Jazzy](https://github.com/realm/jazzy). To generate the documentation, run this command in the PharmaLedger Camera framework root folder (remember to replace VERSION_NUMBER with the version number of the build, eg. 0.1.0):

`jazzy --output docs --copyright "" --author "TrueMed Inc." --author_url https://truemedinc.com --module PharmaLedger_Camera --title "PharmaLedger iOS Camera SDK" --module-version VERSION_NUMBER --skip-undocumented --hide-documentation-coverage`

Before releasing, you can make sure documentation is up to date by not skipping undocumented code.

## Testing

Quickest way to test the Framework is to boot the sample project **Camera Sample**. Make sure that the Swift framework project is included in the project. This way you can quickly make changes to the source files while testing them in an application project. Make sure you don't have the Framework project open in another window.

## Releasing

To build a release framework, open the **PharmaLedger Camera** project and select the release build scheme. After this, build the project and find the release build in the project Output.
