package edu.kit.ipd.sdq.modsim.simspec.export

import edu.kit.ipd.sdq.modsim.simspec.model.behavior.BehaviorContainer
import edu.kit.ipd.sdq.modsim.simspec.model.behavior.Schedules
import edu.kit.ipd.sdq.modsim.simspec.model.behavior.WritesAttribute
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.TypeUtil
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Attribute
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Entity
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Event
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Simulator
import edu.kit.ipd.sdq.modsim.simspec.model.structure.StructurePackage
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl
import org.neo4j.ogm.config.Configuration
import org.neo4j.ogm.cypher.ComparisonOperator
import org.neo4j.ogm.cypher.Filter
import org.neo4j.ogm.session.Session
import org.neo4j.ogm.session.SessionFactory
import java.util.List
import java.util.ArrayList
import edu.kit.ipd.sdq.modsim.simspec.model.behavior.Expression

class DescompExport {
	Session session
	
	/**
	 * Deletes all simulators with the given name from the database.
	 */
	private def deleteConflictingSimulators(String name) {
		val conflicting = session.loadAll(DescompSimulator, new Filter('name', ComparisonOperator.EQUALS, name), 3)
		conflicting.forEach[deleteSimulator]
	}
	
	private def deleteSimulator(DescompSimulator sim) {
		val entities = sim.entities
		val attributes = entities.map[attributes].flatten
		val events = sim.events
		
		session.delete(sim)
		session.delete(entities + attributes + events)
	}
	
	/**
	 * Uploads a simulator to a Neo4J database.
	 * 
	 * @param path The absolute path to the XMI ecore file the contains the simulator.
	 * @param uri The URI of the Neo4J server.
	 * @param username The username used to connect to the database.
	 * @param password The password used to connect to the database.
	 */
	def void uploadSimulator(String path, String uri, String username, String password) {
		StructurePackage.eINSTANCE.eClass
		
		// init resources
		val reg = Resource.Factory.Registry.INSTANCE
		reg.extensionToFactoryMap.put("structure", new XMIResourceFactoryImpl)
		val resSet = new ResourceSetImpl
		
		val fileUri = URI.createFileURI(path)
		val resource = resSet.getResource(fileUri, true)
		
		// load simulator from ecore file
		val sim = resource.contents.filter(Simulator).head
		val behavior = resource.contents.filter(BehaviorContainer).head
		
		// transform to Neo4J model and generate SMT
		val generator = new SMTGenerator()
		
		val simExport = sim.export
		val schedules = behavior.schedules.map[exportSchedules(generator)]
		
		val writes = new ArrayList<DescompWritesAttribute>
		for (event : sim.events) {
			val writesFromEvent = behavior.writesAttributes.filter[it.event == event]
			for (attr : writesFromEvent.map[attribute].toSet) {
				val write = writesFromEvent.filter[it.attribute == attr]
				writes.add(exportWritesAttribute(write, generator))
			}
		}
		//val writes = behavior.writesAttributes.map[exportWritesAttribute(generator)]
		
		// save to database
		val config = new Configuration.Builder()
			.uri(uri)
			.credentials(username, password)
			.build()
		val factory = new SessionFactory(config, DescompSimulator.package.name)
		
		println('Connecting to ' + uri + '...')
		session = factory.openSession
		println('Connected!')
		
		deleteConflictingSimulators(simExport.name)
		
		session.save(simExport)
		session.save(schedules)
		session.save(writes)
		
		println('Simulator saved!')
		
		factory.close
	}
	
	// Transform methods for relationships schedules and writes attribute
	private def exportSchedules(Schedules schedules, SMTGenerator generator) {
		new DescompSchedules => [
			startEvent = schedules.startEvent.export
			endEvent = schedules.endEvent.export
		
			delay = generator.generateDelay(schedules.delay).replaceAll('\n', '')
			condition = generator.generateCondition(schedules.condition).replaceAll('\n', '')
		]
	}
	
	private def exportWritesAttribute(Iterable<WritesAttribute> writes, SMTGenerator generator) {
		val writeFunctions = new ArrayList<Expression>
		val conditions = new ArrayList<Expression>
		for (w : writes) {
			writeFunctions.add(w.writeFunction)
			conditions.add(w.condition)
		}
		
		new DescompWritesAttribute => [
			// event and attribute are (should be) the same for all writes attribute objects
			startEvent = writes.head.event.export
			attribute = writes.head.attribute.export
			
		
			writeFunction = generator.generateWritesAttribute(writes.head.attribute, writeFunctions, conditions).replaceAll('\n', '')
		]
	}
	
	// Transform methods for objects
	private def create result: new DescompSimulator export(Simulator sim) {
		result.name = sim.name
		result.description = sim.description
		result.entities = sim.entities.map[export].toSet
		result.events = sim.events.map[export].toSet
	}
	
	private def create result: new DescompEntity export(Entity entity) {
		result.name = entity.name
		result.attributes = entity.attributes.map[export].toSet
	}
	
	private def create result: new DescompAttribute export(Attribute attribute) {
		result.name = attribute.name
		result.type = TypeUtil.typeName(attribute.type)
	}
	
	private def create result: new DescompEvent export(Event event) {
		result.name = event.name
		result.readAttribute = event.readAttributes.map[export].toSet
	}
}