 Pod::Spec.new do |s|
    
    # meta infos
    s.name             = "CloudKid"
    s.version          = "0.0.3"
    s.summary          = "Lift your code above the harsh realities of CloudKit"
    s.description      = "This is how the kids nowadays do this cloud thing with Swift"
    s.homepage         = "http://flowtoolz.com"
    s.license          = 'MIT'
    s.author           = { "Flowtoolz" => "contact@flowtoolz.com" }
    s.source           = {  :git => "https://github.com/flowtoolz/CloudKid.git",
                            :tag => s.version.to_s }
    
    # compiler requirements
    s.requires_arc = true
    s.swift_version = '5.0'
    
    # minimum platform SDKs
    s.platforms = {:ios => "11.0", :osx => "10.12", :tvos => "11.0"}

    # minimum deployment targets
    s.ios.deployment_target  = '11.0'
    s.osx.deployment_target = '10.12'
    s.tvos.deployment_target = '11.0'

    # sources
    s.source_files = 'Code/**/*.swift'

    # dependencies
    s.dependency 'FoundationToolz', '~> 1.1'
    s.dependency 'SwiftObserver', '~> 6.2'
    s.dependency 'SwiftyToolz', '~> 1.6'
    
end
