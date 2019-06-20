import groovy.json.JsonBuilder

/* Libraries -----------------------------------------------------------------*/

ci = load 'ci/jenkins.groovy'
nix = load 'ci/nix.groovy'
utils = load 'ci/utils.groovy'

/* Small Helpers -------------------------------------------------------------*/

def pkgUrl(build) {
  return utils.getEnv(build, 'PKG_URL')
}

def updateBucketJSON(urls, fileName) {
  /* latest.json has slightly different key names */
  def content = [
    DIAWI: urls.Diawi,
    APK: urls.Apk, IOS: urls.iOS,
    APP: urls.App, MAC: urls.Mac,
    WIN: urls.Win, SHA: urls.SHA
  ]
  def filePath = "${pwd()}/pkg/${fileName}"
  /* it might not exist */
  sh 'mkdir -p pkg'
  def contentJson = new JsonBuilder(content).toPrettyString()
  println "${fileName}:\n${contentJson}"
  new File(filePath).write(contentJson)
  return utils.uploadArtifact(filePath)
}

def prep(type = 'nightly') {
  /* build/downloads all nix deps in advance */
  nix.prepEnv()
  /* rebase unless this is a release build */
  utils.doGitRebase()
  /* ensure that we start from a known state */
  sh 'make clean'
  /* pick right .env and update from params */
  utils.updateEnv(type)

  if (env.TARGET_OS == 'android' || env.TARGET_OS == 'ios') {
    /* Run at start to void mismatched numbers */
    utils.genBuildNumber()
  }

  if (env.TARGET_OS == 'ios') {
    /* install ruby dependencies */
    nix.shell '''
      watchman watch-del-all && \
      bundle install --gemfile=fastlane/Gemfile --quiet
    '''
  }

  if (env.TARGET_OS == 'macos' || env.TARGET_OS == 'linux' || env.TARGET_OS == 'windows') {
    /* node deps, pods, and status-go download */
    utils.nix.shell('''
      watchman watch-del-all && \
      scripts/prepare-for-desktop-platform.sh
    ''', pure: false)
    sh('''
      cp -R translations/ status-modules/translations/ && \
      cp -R status-modules/ node_modules/status-modules/
    ''')
  } else {
    // 1. remove all watchman watches
    // 2. copy translations to node_modules
    // 3. touch node_modules/.copied to avoid copying node_modules again during build
    // run script in the nix shell so that node_modules gets instantiated before attempting the copies
    utils.nix.shell('''
      watchman watch-del-all && \
      cp -R translations/ status-modules/translations/ && \
      chmod u+w node_modules && \
      cp -R status-modules/ node_modules/status-modules/ && \
      touch -t 203812312359 node_modules/.copied && \
      chmod u-w node_modules
    ''')
  }
}

return this
