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

    // Some plugins (e.g. receive_sharing_intent) ship a build.gradle that
    // pins android.compileOptions to Java 1.8 while Kotlin compiles to a
    // newer JVM target, which newer AGP/Kotlin toolchains reject outright.
    // Override every subproject's compileOptions/kotlinOptions to Java 17
    // *after* the plugin's own script has run, so ours wins, matching
    // app/build.gradle.kts. Registered here (before evaluationDependsOn
    // below forces earlier evaluation of some projects) so afterEvaluate
    // is guaranteed to still be registrable.
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
