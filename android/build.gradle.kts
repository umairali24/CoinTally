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

subprojects {
    val fixNamespace = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                if (getNamespace.invoke(android) == null) {
                    var ns = "com.hisaabmate.${project.name.replace("-", "_")}"
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val xml = manifestFile.readText()
                        val match = Regex("package=\"([^\"]+)\"").find(xml)
                        if (match != null) {
                            ns = match.groupValues[1]
                            // Strip package from manifest to avoid AGP 8+ conflict
                            val newXml = xml.replace(Regex("package=\"[^\"]+\""), "")
                            manifestFile.writeText(newXml)
                            println("Stripped package attribute from ${project.name} manifest")
                        }
                    }
                    setNamespace.invoke(android, ns)
                    println("Injected namespace $ns for ${project.name}")
                }
            } catch (e: Exception) {
            }
        }
    }
    if (project.state.executed) {
        fixNamespace()
    } else {
        project.afterEvaluate { fixNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


