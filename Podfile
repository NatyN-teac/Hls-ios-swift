# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

use_frameworks!

target 'pply' do
  pod 'PlayKit'
  pod 'DownloadToGo'
  pod 'PlayKitProviders', '~> 1.3.2'
  end
  

pre_install do |installer|
       def installer.verify_no_static_framework_transitive_dependencies; end
   end

post_install do |installer|
       installer.pods_project.targets.each do |target|
           target.build_configurations.each do |config|
               config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
           if target.name == 'PlayKit'
                  config.build_settings['SWIFT_VERSION'] = '5.0'
           end
           end
       end
   end

