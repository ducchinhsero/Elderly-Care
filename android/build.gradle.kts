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
    afterEvaluate {
        val project = this
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                // Plugin cũ (vd: isar_flutter_libs 3.1.0+1) còn dùng package="..." trong AndroidManifest.xml.
                // AGP 8+ cấm thuộc tính này, nhưng cần namespace tương ứng trong build.gradle.
                // → đọc package=, set thành namespace, rồi xoá khỏi manifest.
                val manifest = file("src/main/AndroidManifest.xml")
                var packageFromManifest: String? = null
                if (manifest.exists()) {
                    val content = manifest.readText()
                    val match = Regex("package\\s*=\\s*\"([^\"]+)\"").find(content)
                    if (match != null) {
                        packageFromManifest = match.groupValues[1]
                        manifest.writeText(
                            content.replace(Regex("\\s+package\\s*=\\s*\"[^\"]+\""), "")
                        )
                    }
                }
                if (androidExt.namespace == null) {
                    androidExt.namespace = packageFromManifest
                        ?: "com.example.${project.name.replace('-', '_')}"
                }
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
