// Copyright (c) 2019 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation

/// Types of build step
public enum BuildStepType: String, Encodable {
    /// Root step
    case main

    /// Target step
    case target

    /// A step that belongs to a target, the type of it is shown by `DetailStepType`
    case detail
}

/// Categories for different kind of build steps
public enum DetailStepType: String, Encodable {

    /// clang compilation step
    case cCompilation

    /// swift compilation step
    case swiftCompilation

    /// Build phase shell script execution
    case scriptExecution

    /// Libtool was used to create a static library
    case createStaticLibrary

    /// Linking of a library
    case linker

    /// Swift Runtime was copied
    case copySwiftLibs

    /// Asset's catalog compilation
    case compileAssetsCatalog

    /// Storyboard compilation
    case compileStoryboard

    /// Auxiliary file
    case writeAuxiliaryFile

    /// Storyboard linked
    case linkStoryboards

    /// Resource file was copied
    case copyResourceFile

    /// Swift Module was merged
    case mergeSwiftModule

    /// Xib file compilation
    case XIBCompilation

    /// With xcodebuild, swift files compilation appear aggregated
    case swiftAggregatedCompilation

    /// Precompile Bridging header
    case precompileBridgingHeader
    //case PrecompileSwiftBridgingHeader

    /// Non categorized step
    case other

    /// For steps that are not a detail step
    case none

    // swiftlint:disable:next cyclomatic_complexity
    public static func getDetailType(signature: String) -> DetailStepType {
        switch signature {
        case Prefix("CompileC "):
            return .cCompilation
        case Prefix("CompileSwift "):
            return .swiftCompilation
        case Prefix("Ld "):
            return .linker
        case Prefix("PhaseScriptExecution "):
            return .scriptExecution
        case Prefix("Libtool "):
            return .createStaticLibrary
        case Prefix("CopySwiftLibs "):
            return .copySwiftLibs
        case Prefix("CompileAssetCatalog"):
            return .compileAssetsCatalog
        case Prefix("CompileStoryboard "):
            return .compileStoryboard
        case Prefix("WriteAuxiliaryFile "):
            return .writeAuxiliaryFile
        case Prefix("LinkStoryboards "):
            return .linkStoryboards
        case Prefix("CpResource "):
            return .copyResourceFile
        case Prefix("MergeSwiftModule "):
            return .mergeSwiftModule
        case Prefix("CompileXIB "):
            return .XIBCompilation
        case Prefix("CompileSwiftSources "):
            return .swiftAggregatedCompilation
        case Prefix("PrecompileSwiftBridgingHeader "):
            return .precompileBridgingHeader
        default:
            return .other
        }
    }
}

/// Represents a Step in the BuildLog
public struct BuildStep: Encodable {

    /// The type of the step
    public let type: BuildStepType

    /// The name of the machine as determined by `MachineNameReader`
    public let machineName: String

    /// The unique identifier of the build
    public let buildIdentifier: String

    /// The identifier of the step
    public let identifier: String

    /// The identifier of the parent step
    public let parentIdentifier: String

    /// Value taken from `IDEActivityLogSection.domainType`
    /// It contains values that can be used to identify the type of the step.
    /// For example: `com.apple.dt.IDE.BuildLogSection` or `Xcode.IDEActivityLogDomainType.target.product-type.target`
    public let domain: String

    /// The title of the Step <br>
    /// In steps of type BuildStepType.detail this contains the file that was compiled
    public let title: String

    /// The signature of the Step. This may contain more detail than the Title
    /// In steps of type BuildStepType.detail this contains more information about the compilation
    public let signature: String

    /// The start date of the step represented in the format ISO8601
    public let startDate: String

    /// The start date of the step represented in the format ISO8601
    public let endDate: String

    /// The timestap in which the step started represented as Unix epoch <br>
    /// - For steps of type BuildStepType.main this is the date in which the build started
    /// - Some subSteps may have a startTimestamp before the main's startTimestamp.
    /// That behaviour has been found in steps of `DetailStepType.copyResourceFile`.
    /// Probably meaning that the file was cached
    public let startTimestamp: Int64

    /// The timestap in which the step ended represented as Unix epoch
    /// For steps of type BuildStepType.main this is the date in which the build ended
    public let endTimestamp: Int64

    /// The number of seconds the step lasted.
    /// For steps of type BuildStepType.main this is the total duration of the build.
    public let duration: Int64

    /// For builds of type
    public let detailStepType: DetailStepType

    /// The status of the build.
    /// Examples: succeeded, failed
    public let buildStatus: String

    /// The Xcode's schema executed
    public let schema: String

    /// The `BuildStep`s that belong to this step.
    /// Those subSteps will have this step `identifier` as their `parentIdentifier`
    public var subSteps = [BuildStep]()

    /// The number of warnings found in this step. <br>
    /// - For `BuildStep`s of type `BuildStepType.main` is the total number of warnings of the project
    /// - For `BuildStep`s of type `target` is the total number of warnings in its subSteps.
    public var warningCount: Int

    /// The number of errors found in this step. <br>
    /// - For `BuildStep`s of type `BuildStepType.main` is the total number of errors of the project
    /// - For `BuildStep`s of type `target` is the total number of errors in its subSteps.
    public var errorCount: Int

    /// Only used for compilation steps.
    /// It could be arm64, armv7, and so on
    public let architecture: String

    /// URL of the document in a build of type `.detail`
    public let documentURL: String

    /// The warnings found in this step
    // public let warnings: [Notice]?

    /// The errors found in this step
    // public let errors: [Notice]?

    /// Notes found in this step
    public let notes: [Notice]?

    /// Swift function's compilation times
    /// If the project was compiled with the swift flags `-Xfrontend -debug-time-function-bodies`
    /// This field will be populated
    public var swiftFunctionTimes: [FunctionTime]?
}

/// Extension used to flatten the three of a `BuildStep`
public extension BuildStep {

    /// Traverse a tree of BuildStep and returns a flatten Array.
    /// Used in some `BuildReporter` because is easy to handle an Array. <br>
    /// This used to be a recursive function, but it was taken too long.
    /// Since it's not recursive, it only flattens the first 3 levels of the tree.
    func flatten() -> [BuildStep] {
        var steps = [BuildStep]()
        var noSubSteps = self
        noSubSteps.subSteps = [BuildStep]()
        steps.append(noSubSteps)
        for subStep in self.subSteps {
            steps.append(contentsOf: flattenSubstep(subStep: subStep))
        }
        return steps
    }

    func flattenSubstep(subStep: BuildStep) -> [BuildStep] {
        var details = [BuildStep]()
        var noSubSteps = subStep
        noSubSteps.subSteps = [BuildStep]()
        details.append(noSubSteps)
        for detail in subStep.subSteps {
            var noSubSteps = detail
            noSubSteps.subSteps = [BuildStep]()
            details.append(noSubSteps)
            if detail.subSteps.isEmpty == false {
                details.append(contentsOf: detail.subSteps)
            }
        }
        return details
    }

}
