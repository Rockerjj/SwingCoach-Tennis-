platform :ios, '17.0'
use_frameworks!

target 'TennisIQ' do
  pod 'MediaPipeTasksVision'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end

  # MediaPipe ships its xcframework as a static archive wrapped in a .framework
  # bundle (binary at MediaPipeTasksCommon.framework/MediaPipeTasksCommon, no .a
  # extension). CocoaPods' default xcconfig treats it as a static lib and adds
  # `-l"MediaPipeTasksCommon"`, which the linker can't resolve. Patch the
  # consumer xcconfigs to use `-framework` and to include the
  # XCFrameworkIntermediates dir in FRAMEWORK_SEARCH_PATHS at link time.
  mediapipe_libs = ['MediaPipeTasksCommon', 'MediaPipeTasksVision']
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, config|
      paths = aggregate_target.xcconfig_path(config_name)
      content = File.read(paths)
      changed = false
      mediapipe_libs.each do |lib|
        if content.include?(%(-l"#{lib}"))
          content.gsub!(%(-l"#{lib}"), %(-framework "#{lib}"))
          changed = true
        end
      end
      mediapipe_search_paths = mediapipe_libs.map { |l| %("${PODS_XCFRAMEWORKS_BUILD_DIR}/#{l}") }.join(' ')
      if content =~ /^FRAMEWORK_SEARCH_PATHS = \$\(inherited\)(?! "\$\{PODS_XCFRAMEWORKS_BUILD_DIR\}\/MediaPipeTasksCommon")/
        content.sub!(/^FRAMEWORK_SEARCH_PATHS = \$\(inherited\)/,
                     "FRAMEWORK_SEARCH_PATHS = $(inherited) #{mediapipe_search_paths}")
        changed = true
      end
      File.write(paths, content) if changed
    end
  end
end
