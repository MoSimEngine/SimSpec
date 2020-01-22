/*
 * generated by Xtext 2.17.0
 */
package edu.kit.ipd.sdq.modsim.simspec.language.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import edu.kit.ipd.sdq.modsim.simspec.model.structure.StructureFactory
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Event
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Simulator
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import java.io.IOException

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class SpecificationLanguageGenerator extends AbstractGenerator {

	def create result: StructureFactory.eINSTANCE.createEvent copyEvent(Event e) {
		result.id = e.id
		result.name = e.name
		result.readAttributes.addAll(e.readAttributes.clone)
		
//		if (e instanceof GEvent) {
//			for (s : e.schedules) {
//				val sched = SpecificationSyntaxFactory.eINSTANCE.createSchedules
//				sched.startEvent = result
//				sched.endEvent = copyEvent(s.endEvent, container)
//				
//				container.schedules.add(sched)
//			}
//		}
	}

	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		//val factory = SpecificationSyntaxFactory.eINSTANCE
		//val container = factory.createSyntaxContainer			
		
		val sim = resource.allContents.filter(Simulator).head as Simulator;
		val events = sim.events.map[copyEvent].clone
		
		sim.events.clear
		sim.events.addAll(events)
		
		
		// write ecore to file
		val reg = Resource.Factory.Registry.INSTANCE
		reg.extensionToFactoryMap.put("structure", new XMIResourceFactoryImpl)
		
		val resSet = new ResourceSetImpl
//		val resource = resSet.createResource(fsa.createURI("data/test.structure"))
		val res = resSet.createResource(fsa.getURI("output.structure"))
		
		res.contents.add(sim)
		//res.contents.add(container)
		
		try {
			res.save(#{})
		} catch (IOException e) {
			e.printStackTrace
		}
	}
}
