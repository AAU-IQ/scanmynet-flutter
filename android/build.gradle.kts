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

// The bundled `tools` AAR is an `implementation` dependency of this library, so
// the CONSUMING app resolves it on its own runtime classpath — not us. Declaring
// these repositories only on this project (plain `allprojects`) therefore left a
// pub.dev consumer with "Could not find org.bitbucket.creativeadvtech:tools",
// because `:app` is our sibling, not our descendant.
//
// Inject them into every project of the consuming build instead. `projectDir` is
// captured here (this script's project) so the URL points at THIS package
// wherever pub unpacked it, rather than at whichever project is being configured.
val bundledMavenRepo = uri("$projectDir/local-maven-repo")

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        // Private AARs bundled in android/local-maven-repo/ — no external server needed.
        maven { url = bundledMavenRepo }
        // Required for com.github.stealthcopter:AndroidNetworkTools (transitive dep of tools).
        maven { url = uri("https://jitpack.io") }
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
        consumerProguardFiles("consumer-rules.pro")
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
    // Private AARs served from android/local-maven-repo/ (proper Maven layout avoids the
    // "direct local .aar deps not supported when building an AAR" AGP restriction).
    // Gradle reads the tools POM and resolves all transitive deps automatically.
    implementation("org.bitbucket.creativeadvtech:tools:1.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
