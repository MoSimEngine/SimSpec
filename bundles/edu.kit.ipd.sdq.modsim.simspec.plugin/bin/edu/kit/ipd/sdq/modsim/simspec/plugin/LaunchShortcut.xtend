package edu.kit.ipd.sdq.modsim.simspec.plugin

import org.eclipse.debug.ui.ILaunchShortcut
import org.eclipse.jface.viewers.ISelection
import org.eclipse.ui.IEditorPart
import org.eclipse.jface.viewers.IStructuredSelection
import edu.kit.ipd.sdq.modsim.simspec.export.DescompExport
import java.util.Properties
import java.io.FileReader
import java.io.FileNotFoundException
import java.io.IOException
import java.io.File

class LaunchShortcut implements ILaunchShortcut {
	static val PROPERTIES_FILE = 'export.properties'
	
	static val PROP_URI_KEY = 'neo4j.uri'
	static val PROP_NAME_KEY = 'neo4j.username'
	static val PROP_PASSWORD_KEY = 'neo4j.password'
	
	override launch(ISelection selection, String mode) {
		if (!(selection instanceof IStructuredSelection)) {
			//TODO: useful error message
			return
		}
		
		val structured = selection as IStructuredSelection
		
		if (!(structured.firstElement instanceof org.eclipse.core.internal.resources.File)) {
			//TODO: another useful error
			return
		}
		
		val file = structured.firstElement as org.eclipse.core.internal.resources.File
		val outputFile = new File(file.locationURI)
		val projectRoot = new File(file.project.locationURI)
		
		val properties = getExportProperties(projectRoot)
		if (properties === null) return
		
		val uri = properties.getProperty(PROP_URI_KEY)
		val username = properties.getProperty(PROP_NAME_KEY)
		val password = properties.getProperty(PROP_PASSWORD_KEY)
		
		//val output = new java.io.File(projectRoot, OUTPUT_FILE)
		val export = new DescompExport
		export.uploadSimulator(outputFile.absolutePath, uri, username, password)
	}
	
	def getExportProperties(File projectRoot) {
		val propFile = new File(projectRoot, PROPERTIES_FILE)
		var FileReader reader
		try {
			val prop = new Properties
			reader = new FileReader(propFile)
			prop.load(reader)
			return prop
		} catch (FileNotFoundException e) {
			println('export.properties file not found!')
			e.printStackTrace
		} catch (IOException e) {
			println('Invalid properties file!')
			e.printStackTrace
		} finally {
			reader.close
		}
		return null
	}
	
	override launch(IEditorPart editor, String mode) {
		//TODO: do sth useful
	}
	
}