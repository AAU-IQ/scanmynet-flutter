allprojects {
    repositories {
        google()
        mavenCentral()
        // The scanmynet_sdk plugin depends on the RouteThis `tools` AAR, which
        // is published to the local Maven repo via
        // `./gradlew :tools:publishToMavenLocal` (scanmynet-android). A real
        // consumer app would point this at the private Maven/Artifactory repo.
        mavenLocal()
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
