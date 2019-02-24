# Swift REST Client Generator for Google APIs

This project contains Swift code that generates a API clients from Discovery Documents
produced by the [Google API Discovery Service](https://developers.google.com/discovery/).

It is experimental work-in-progress, but provides a good start
at calling many Google APIs from Swift. Our focus is on supporting
calls from server-side and command-line Swift applications, but
calls from any platform with Swift support should be possible.

## Usage

API clients are be produced by running the generator with Discovery
Documents downloaded from the Discovery Service. 
Running the following writes a client library to the directory named <output>
(or the current directory if `--output` is unspecified):

```
% google-api-swift-generator <filename> --output <output>
```

This project also includes an experimental CLI generator that
generates command-line interfaces for APIs. These CLIs depend
on the generated client libraries and are produced with the
`google-cli-swift-generator` command.
Running the following writes a CLI `main.swift` 
to the directory named <output>
(or the current directory if `--output` is unspecified):
 
```
% google-cli-swift-generator <filename> --output <output>
```

The [Examples](Examples) directory contains several example 
clients including scripts for generating both client libraries and 
CLIs.

## Contributing

We'd love to collaborate on this. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Copyright

Copyright 2019, Google Inc.

## License

Released under the Apache 2.0 license.
