allprojects {
    repositories {
        google()
        mavenCentral()
        // Private AARs bundled in the SDK repo — no local Maven install needed.
        maven { url = uri("${rootProject.projectDir}/../../android/local-maven-repo") }
        // `tools` pulls JitPack-hosted transitive deps (AndroidNetworkTools,
        // traceroute) — mirror the repos the scanmynet-android build uses.
        maven { url = uri("https://jitpack.io") }
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
