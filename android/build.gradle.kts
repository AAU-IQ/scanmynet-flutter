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
    // Private AARs bundled in android/libs/ — no local Maven publish or external repo needed.
    // Update these files when a new version of tools/traceroute is released.
    implementation(files("libs/tools-1.0.aar"))
    implementation(files("libs/traceroute-1.0.0.aar"))

    // Public transitive deps declared in the tools POM (compile scope — needed at compile time).
    implementation("com.squareup.retrofit2:converter-gson:3.0.0")
    implementation("com.squareup.okhttp3:logging-interceptor:5.3.2")
    implementation("com.squareup.retrofit2:retrofit:3.0.0")
    implementation("com.squareup.retrofit2:adapter-rxjava3:3.0.0")
    implementation("com.squareup.retrofit2:converter-scalars:3.0.0")
    implementation("com.squareup.retrofit2:converter-jaxb:3.0.0")

    // Public transitive deps declared in the tools POM (runtime scope).
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("com.android.volley:volley:1.2.1")
    implementation("com.stanfy:gson-xml-java:0.1.7")
    implementation("io.reactivex.rxjava3:rxkotlin:3.0.1")
    implementation("io.reactivex.rxjava3:rxandroid:3.0.2")
    implementation("io.reactivex.rxjava3:rxjava:3.1.12")
    implementation("fr.bmartel:jspeedtest:1.32.1")
    implementation("com.google.firebase:firebase-crashlytics-buildtools:3.0.6")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("androidx.work:work-runtime-ktx:2.11.1")
    implementation("com.github.stealthcopter:AndroidNetworkTools:0.4.5.3") // via JitPack

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
