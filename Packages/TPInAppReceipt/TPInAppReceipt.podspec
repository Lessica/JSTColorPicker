Pod::Spec.new do |s|

	s.name         = "TPInAppReceipt"
	s.version      = "3.3.2"
	s.summary      = "Reading and Validating In App Purchase Receipt Locally"
	s.description  = "A lightweight iOS/OSX library for reading and validating Apple In App Purchase Receipt locally. Pure swift, No OpenSSL!"

	s.homepage     = "https://github.com/tikhop/TPInAppReceipt"
	s.license      = "MIT"
	s.source       = { :git => "https://github.com/tikhop/TPInAppReceipt.git", :tag => "#{s.version}" }

	s.author       = { "Pavel Tikhonenko" => "hi@tikhop.com" }

	s.swift_versions = ['5.3']
	s.ios.deployment_target = '10.0'
	s.osx.deployment_target = '10.12'
	s.tvos.deployment_target = '10.0'
	s.watchos.deployment_target = '6.2'
	s.requires_arc = true

	
	s.subspec 'Core' do |core|
		core.exclude_files = "Sources/Objc/*.{swift}"
		core.source_files  = "Sources/*.{swift}"
		core.resources  = "Sources/AppleIncRootCertificate.cer", "Sources/StoreKitTestCertificate.cer"
		core.dependency 'ASN1Swift', '~> 1.2.3'
	end
	
	s.subspec 'Objc' do |objc|
		objc.source_files  = "Sources/Objc/*.{swift}"
		objc.dependency 'TPInAppReceipt/Core'
	end
	
	s.default_subspecs = 'Core'
	
end
