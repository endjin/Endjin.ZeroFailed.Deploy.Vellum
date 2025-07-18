# Endjin.ZeroFailed.Deploy.Vellum

[![Build Status](https://github.com/endjin/Endjin.ZeroFailed.Deploy.Vellum/actions/workflows/build.yml/badge.svg)](https://github.com/endjin/Endjin.ZeroFailed.Deploy.Vellum/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/release/endjin/Endjin.ZeroFailed.Deploy.Vellum.svg)](https://github.com/endjin/Endjin.ZeroFailed.Deploy.Vellum/releases)
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Endjin.ZeroFailed.Deploy.Vellum?color=blue)](https://www.powershellgallery.com/packages/Endjin.ZeroFailed.Deploy.Vellum)
[![License](https://img.shields.io/github/license/endjin/Endjin.ZeroFailed.Deploy.Vellum.svg)](https://github.com/endjin/Endjin.ZeroFailed.Deploy.Vellum/blob/main/LICENSE)


A [ZeroFailed](https://github.com/zerofailed/ZeroFailed) extension encapsulating a process to build static web sites using the [Vellum](https://github.com/endjin/Endjin.StaticSiteGen) tooling.

## Overview

| Component Type | Included | Notes                                                                                                                                                    |
| -------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tasks          | yes      |                                                                                                                                                          |
| Functions      | yes      |                                                                                                                                                          |
| Processes      | no      | TODO |

For more information about the different component types, please refer to the [ZeroFailed documentation](https://github.com/zerofailed/ZeroFailed/blob/main/README.md#extensions).

This extension consists of the following feature groups, click the links to see their documentation:

- Installing Vellum global tool (***NOTE**: Requires a GitHub token with access to this [private repo](https://github.com/endjin/Endjin.StaticSiteGen)*)
- Runs the static site generator
- Uses Vite to optimise the generated site

## Dependencies

| Extension                                                                        | Reference Type | Version |
| -------------------------------------------------------------------------------- | -------------- | ------- |
| [ZeroFailed.Deploy.Azure](https://github.com/zerofailed/ZeroFailed.Deploy.Azure) | git            | `main`  |

## Getting Started

TODO


## Usage

For an example of using this extension to deploy a Vellum-based static web site, please take a look at [this example repo](https://github.com/endjin/fabric-weekly-info).