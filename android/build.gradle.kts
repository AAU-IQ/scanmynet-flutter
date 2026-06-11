group = "com.creativeadvtech.scanmynet_sdk"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.3.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.0.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // RouteThis ScanMyNet `tools` AAR is published here via
        // `./gradlew :tools:publishToMavenLocal` from the scanmynet-android repo.
        // TODO(distribution): replace with the private Maven/Artifactory repo
        // once one exists, so consumers don't need a local publish.
        mavenLocal()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.creativeadvtech.scanmynet_sdk"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // RouteThis ScanMyNet native SDK (the `tools` AAR). Pulls retrofit/okhttp
    // transitively (compile scope) and rxjava/rxandroid (runtime scope).
    implementation("org.bitbucket.creativeadvtech:tools:1.0")
    // `tools` exposes RxJava only as a runtime transitive dep, but its public
    // `scan()` returns `Single<ReportResponseDto>`, so we need RxJava at compile
    // time to subscribe to it.
    implementation("io.reactivex.rxjava3:rxjava:3.1.12")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
