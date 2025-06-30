// Copyright © 2024 Hardcore Engineering Inc. Use of this source code is governed by the Apache 2.0 license.

import kotlinx.collections.immutable.PersistentList
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.plus
import org.jetbrains.intellij.build.ApplicationInfoProperties
import org.jetbrains.intellij.build.BaseIdeaProperties
import org.jetbrains.intellij.build.BuildContext
import org.jetbrains.intellij.build.BuildOptions
import org.jetbrains.intellij.build.BuildPaths.Companion.COMMUNITY_ROOT
import org.jetbrains.intellij.build.CommunityRepositoryModules
import org.jetbrains.intellij.build.DEFAULT_BUNDLED_PLUGINS
import org.jetbrains.intellij.build.FileAssociation
import org.jetbrains.intellij.build.JewelMavenArtifacts
import org.jetbrains.intellij.build.JvmArchitecture
import org.jetbrains.intellij.build.LibcImpl
import org.jetbrains.intellij.build.LinuxDistributionCustomizer
import org.jetbrains.intellij.build.MacDistributionCustomizer
import org.jetbrains.intellij.build.MacOsCodesignIdentity
import org.jetbrains.intellij.build.ProprietaryBuildTools
import org.jetbrains.intellij.build.WindowsDistributionCustomizer
import org.jetbrains.intellij.build.impl.BuildContextImpl
import org.jetbrains.intellij.build.impl.PluginLayout.Companion.pluginAuto
import org.jetbrains.intellij.build.io.copyDir
import org.jetbrains.intellij.build.io.copyFileToDir
import org.jetbrains.intellij.build.kotlin.KotlinBinaries
import org.jetbrains.intellij.build.kotlin.KotlinPluginBuilder
import java.nio.file.Path
import java.util.Locale

//"//plugins/git4idea:vcs-git",
//"//plugins/git4idea/shared",
//"//plugins/git4idea/frontend",
//"//plugins/git-features-trainer:vcs-git-featuresTrainer",
//"//images",
//"//plugins/svn4idea:vcs-svn",
//"//plugins/github/github-core:vcs-github",
//"//plugins/hg4idea:vcs-hg",
//"//plugins/terminal",
//"//plugins/terminal/frontend",
//"//plugins/terminal/backend",
//"//plugins/stats-collector",
//"//plugins/editorconfig:editorconfig-plugin-main",
//"//plugins/changeReminder",
//"//plugins/sh",
//"//plugins/terminal/sh",
//"//platform/settings-sync-core:settingsSync-core",
//"//plugins/settings-sync/jba:settingsSync",
//"//plugins/laf/macos",
//"//plugins/laf/win10",
//"//plugins/keymaps/eclipse-keymap:keymap-eclipse",
//"//plugins/keymaps/visual-studio-keymap:keymap-visualStudio",
//"//plugins/keymaps/netbeans5.6-keymap:keymap-netbeans",
//"//platform/warmup",
//"//platform/smart-update",
//"//platform/new-ui-onboarding",
//"//platform/new-users-onboarding",
//"//plugins/github/community",
//"//plugins/gitlab/gitlab-community:vcs-gitlab-community",
//"//plugins/gitlab/gitlab-yaml:vcs-gitlab-yaml",
//"//plugins/github/github-json:vcs-github-json",
//"//plugins/git-modal-commit:vcs-git-commit-modal",
val HULY_BUNDLED_PLUGINS: PersistentList<String> = persistentListOf(
  "intellij.platform.images",
) + sequenceOf(
  //"intellij.java.ide.customization",
  "intellij.copyright",
  //"intellij.properties",
  "intellij.terminal",
  //"intellij.textmate",
  //"intellij.editorconfig.plugin",
  "intellij.settingsSync",
  //"intellij.configurationScript",
  //"intellij.json",
  //"intellij.yaml",
  //"intellij.html.tools",
  "intellij.tasks.core",
  //"intellij.repository.search",
  //"intellij.maven",
  //"intellij.gradle",
  //"intellij.android.gradle.declarative.lang.ide",
  //"intellij.android.gradle.dsl",
  //"intellij.gradle.java",
  "intellij.vcs.git",
  "intellij.vcs.git.commit.modal",
  "intellij.vcs.svn",
  "intellij.vcs.hg",
  //"intellij.groovy",
  //"intellij.junit",
  //"intellij.testng",
  //"intellij.java.i18n",
  //"intellij.java.byteCodeViewer",
  //"intellij.java.coverage",
  //"intellij.java.decompiler",
  //"intellij.eclipse",
  //"intellij.platform.langInjection",
  //"intellij.java.debugger.streams",
  //"intellij.completionMlRanking",
  //"intellij.completionMlRankingModels",
  "intellij.statsCollector",
  "intellij.sh",
  //"intellij.markdown",
  //"intellij.mcpserver",
  //"intellij.webp",
  //"intellij.grazie",
  "intellij.featuresTrainer",
  //"intellij.searchEverywhereMl",
  //"intellij.marketplaceMl",
  //"intellij.toml",
  //KotlinPluginBuilder.MAIN_KOTLIN_PLUGIN_MODULE,
  "intellij.keymap.eclipse",
  "intellij.keymap.visualStudio",
  "intellij.keymap.netbeans",
  //"intellij.performanceTesting",
  //"intellij.turboComplete",
  //"intellij.compose.ide.plugin",
)

internal suspend fun createHulyBuildContext(
  options: BuildOptions = BuildOptions(),
  projectHome: Path = COMMUNITY_ROOT.communityRoot,
): BuildContext {
  return BuildContextImpl.createContext(projectHome = projectHome,
                                        productProperties = HulyProperties(COMMUNITY_ROOT.communityRoot, options),
                                        setupTracer = true,
                                        proprietaryBuildTools = ProprietaryBuildTools(
                                          scrambleTool = null,
                                          signTool = MacOsSignTool(),
                                          macOsCodesignIdentity = MacOsCodesignIdentity(""),
                                          featureUsageStatisticsProperties = null,
                                          artifactsServer = null,
                                          licenseServerHost = null,
                                        ),
                                        options = options)
}

open class HulyProperties(private val communityHomeDir: Path, options: BuildOptions) : BaseIdeaProperties() {
  companion object {
    val MAVEN_ARTIFACTS_ADDITIONAL_MODULES: PersistentList<String> = persistentListOf(
      //"intellij.tools.jps.build.standalone",
      //"intellij.devkit.runtimeModuleRepository.jps",
      //"intellij.devkit.jps",
      "intellij.idea.community.build.tasks",
      //"intellij.platform.debugger.testFramework",
      "intellij.platform.vcs.testFramework",
      //"intellij.platform.externalSystem.testFramework",
      //"intellij.maven.testFramework",
      //"intellij.tools.reproducibleBuilds.diff",
      //"intellij.space.java.jps",
      *JewelMavenArtifacts.STANDALONE.keys.toTypedArray(),
    )
  }

  override val baseFileName: String
    get() = "huly-code"

  init {
    platformPrefix = "Huly"
    applicationInfoModule = "hulylabs.intellij.customization"
    scrambleMainJar = false
    useSplash = true
    buildCrossPlatformDistribution = true

    productLayout.productImplementationModules = listOf(
      "intellij.platform.starter",
      "hulylabs.intellij.customization",
    )
    productLayout.bundledPluginModules = HULY_BUNDLED_PLUGINS // + sequenceOf("intellij.vcs.github.community")

    productLayout.prepareCustomPluginRepositoryForPublishedPlugins = false
    productLayout.buildAllCompatiblePlugins = false
    productLayout.pluginLayouts = CommunityRepositoryModules.COMMUNITY_REPOSITORY_PLUGINS.addAll(listOf(
      //JavaPluginLayout.javaPlugin(),
      //CommunityRepositoryModules.androidPlugin(allPlatforms = true),
      //CommunityRepositoryModules.groovyPlugin(),
      pluginAuto("redhat.lsp4ij") { spec ->
        spec.withModuleLibrary("eclipse.lsp4j", "redhat.lsp4ij", "org.eclipse.lsp4j-0.21.1.jar")
        spec.withModuleLibrary("eclipse.lsp4j.debug", "redhat.lsp4ij", "org.eclipse.lsp4j.debug-0.21.1.jar")
        spec.withModuleLibrary("vladsch.flexmark", "redhat.lsp4ij", "flexmark-0.64.8.jar")
        spec.withModuleLibrary("nibor.autolink", "redhat.lsp4ij", "autolink-0.11.0.jar")
      },
      pluginAuto("hulylabs.langconfigurator") { spec ->
        spec.withModuleLibrary("tukaani.xz", "hulylabs.langconfigurator", "xz-1.10.jar")
        spec.withModuleLibrary("esotericsoftware.yamlbeans", "hulylabs.langconfigurator", "yamlbeans-1.17.jar")
      },
      pluginAuto("hulylabs.treesitter") { spec ->
        spec.withModuleLibrary("tree-sitter-libs", "hulylabs.treesitter", "tree-sitter-libs.jar")
      },
      pluginAuto("hulylabs.aicompletion") { spec ->
        spec.withModuleLibrary("eclipse.lsp4j.jsonrpc", "hulylabs.aicompletion", "eclipse.lsp4j.jsonrpc-0.23.1.jar")
      },
      pluginAuto("hulylabs.cline") { spec ->
        spec.withModuleLibrary("caoccao.javet", "hulylabs.cline", "javet-4.1.1.jar")
        spec.excludeModuleLibrary("eclipse.lsp4j", "hulylabs.cline")
        val osName = options.targetOs.first().name.lowercase(Locale.ENGLISH)
        val archName = if (options.targetArch == JvmArchitecture.aarch64) "arm64" else "x86_64"
        val libName = "caoccao.javet.node.${osName}.${archName}.i18n"
        spec.withModuleLibrary(libName, "hulylabs.cline", "${libName}.jar")
      }
    ))

    productLayout.addPlatformSpec { layout, _ ->
      layout.withModule("intellij.platform.duplicates.analysis")
      layout.withModule("intellij.platform.structuralSearch")
    }

    mavenArtifacts.forIdeModules = true
    mavenArtifacts.additionalModules = mavenArtifacts.additionalModules.addAll(MAVEN_ARTIFACTS_ADDITIONAL_MODULES)
    mavenArtifacts.squashedModules = mavenArtifacts.squashedModules.addAll(persistentListOf(
      "intellij.platform.util.base",
      "intellij.platform.util.zip",
    ))

    //versionCheckerConfig = CE_CLASS_VERSIONS
    baseDownloadUrl = "https://dist.huly.io/code/"
    buildDocAuthoringAssets = true

    additionalVmOptions = persistentListOf(
      "-Dllm.show.ai.promotion.window.on.start=false",
      "-Djb.consents.confirmation.enabled=false",
      "-Didea.show.splash.longer=true"
    )
  }

  override suspend fun copyAdditionalFiles(context: BuildContext, targetDir: Path) {
    super.copyAdditionalFiles(context, targetDir)

    copyFileToDir(context.paths.communityHomeDir.resolve("LICENSE.txt"), targetDir)
    copyFileToDir(context.paths.communityHomeDir.resolve("NOTICE.txt"), targetDir)

    copyDir(
      sourceDir = context.paths.communityHomeDir.resolve("build/conf/ideaCE/common/bin"),
      targetDir = targetDir.resolve("bin"),
    )
    bundleExternalPlugins(context, targetDir)
  }

  protected open suspend fun bundleExternalPlugins(context: BuildContext, targetDirectory: Path) {
  }

  override fun createWindowsCustomizer(projectHome: String): WindowsDistributionCustomizer = HulyCodeWindowsDistributionCustomizer()
  override fun createLinuxCustomizer(projectHome: String): LinuxDistributionCustomizer = HulyCodeLinuxDistributionCustomizer()
  override fun createMacCustomizer(projectHome: String): MacDistributionCustomizer = HulyCodeMacDistributionCustomizer()

  protected open inner class HulyCodeWindowsDistributionCustomizer : WindowsDistributionCustomizer() {
    init {
      icoPath = "${communityHomeDir}/build/conf/hulycode/win/images/idea_CE.ico"
      icoPathForEAP = "${communityHomeDir}/build/conf/hulycode/win/images/idea_CE_EAP.ico"
      installerImagesPath = "${communityHomeDir}/build/conf/hulycode/win/images"
      fileAssociations = listOf("ts", "rs", "toml", "zig")
    }

    override fun getFullNameIncludingEdition(appInfo: ApplicationInfoProperties) = "Huly Code"

    override fun getFullNameIncludingEditionAndVendor(appInfo: ApplicationInfoProperties) = "Huly Code"

    override fun getUninstallFeedbackPageUrl(appInfo: ApplicationInfoProperties): String {
      return "" //"https://www.jetbrains.com/idea/uninstall/?edition=IC-${appInfo.majorVersion}.${appInfo.minorVersion}"
    }
  }

  protected open inner class HulyCodeLinuxDistributionCustomizer : LinuxDistributionCustomizer() {
    init {
      iconPngPath = "${communityHomeDir}/build/conf/hulycode/linux/images/icon_CE_128.png"
      iconPngPathForEAP = "${communityHomeDir}/build/conf/hulycode/linux/images/icon_CE_EAP_128.png"
      snapName = "huly-code"
      snapDescription =
        "A fast, minimal IDE for productive coding."
    }

    override fun getRootDirectoryName(appInfo: ApplicationInfoProperties, buildNumber: String) = "idea-IC-$buildNumber"

    override fun generateExecutableFilesPatterns(context: BuildContext, includeRuntime: Boolean, arch: JvmArchitecture, targetLibcImpl: LibcImpl): Sequence<String> {
      return super.generateExecutableFilesPatterns(context, includeRuntime, arch,targetLibcImpl)
        .plus(KotlinBinaries.kotlinCompilerExecutables)
        .filterNot { it == "plugins/**/*.sh" }
    }
  }

  protected open inner class HulyCodeMacDistributionCustomizer : MacDistributionCustomizer() {
    init {
      icnsPath = "${communityHomeDir}/build/conf/hulycode/mac/images/idea.icns"
      icnsPathForEAP = "${communityHomeDir}/build/conf/hulycode/mac/images/communityEAP.icns"
      urlSchemes = listOf("huly-code")
      associateIpr = true
      fileAssociations = FileAssociation.from("ts", "rs", "toml", "zig")
      bundleIdentifier = "app.huly.HulyCode"
      dmgImagePath = "${communityHomeDir}/build/conf/hulycode/mac/images/dmg_background.png"
    }

    override fun getRootDirectoryName(appInfo: ApplicationInfoProperties, buildNumber: String): String {
      return if (appInfo.isEAP) {
        "Huly Code ${appInfo.majorVersion}.${appInfo.minorVersionMainPart}.app"
      }
      else {
        "Huly Code.app"
      }
    }

    override fun generateExecutableFilesPatterns(context: BuildContext, includeRuntime: Boolean, arch: JvmArchitecture): Sequence<String> {
      return super.generateExecutableFilesPatterns(context, includeRuntime, arch)
        .plus(KotlinBinaries.kotlinCompilerExecutables)
        .plus("jbr/Contents/Home/lib/jspawnhelper")
        .filterNot { it == "plugins/**/*.sh" }
    }
  }

  override fun getSystemSelector(appInfo: ApplicationInfoProperties, buildNumber: String): String {
    return "HulyCode${appInfo.majorVersion}.${appInfo.minorVersionMainPart}"
  }

  override fun getBaseArtifactName(appInfo: ApplicationInfoProperties, buildNumber: String) = "huly-code-$buildNumber"

  override fun getOutputDirectoryName(appInfo: ApplicationInfoProperties) = "huly-code"
}