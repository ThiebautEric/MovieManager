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
    // Force compileSdk 36 sur TOUS les modules Android (l'app ET les plugins) :
    // file_picker / flutter_plugin_android_lifecycle exigent une compilation
    // contre l'API 36, alors que le SDK Flutter installé cible encore 34 par
    // défaut. Enregistré ici, AVANT le bloc evaluationDependsOn ci-dessous, pour
    // que afterEvaluate soit posé avant que les sous-projets soient évalués.
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileSdkVersion"(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
