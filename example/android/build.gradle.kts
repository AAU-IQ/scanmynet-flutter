// Deliberately only the stock repositories a `flutter create` app ships with.
// The plugin registers its own bundled AAR repo (and JitPack) with the build,
// so the example exercises the exact resolution path a pub.dev consumer gets.
// Do NOT add the plugin's local-maven-repo here — doing so previously masked a
// bug where consumers could not resolve `tools` at all.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
