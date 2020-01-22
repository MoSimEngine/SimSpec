package edu.kit.ipd.sdq.modsim.simspec.export

import org.neo4j.ogm.annotation.NodeEntity
import org.neo4j.ogm.annotation.Id
import org.neo4j.ogm.annotation.GeneratedValue
import org.neo4j.ogm.annotation.Property
import org.eclipse.xtend.lib.annotations.Accessors
import org.neo4j.ogm.annotation.Relationship
import java.util.Set
import java.util.HashSet

abstract class DescompIdentifier {
	@Id @GeneratedValue
	@Accessors Long id
	
	@Property
	@Accessors String name	
}

@NodeEntity(label='Simulator')
class DescompSimulator extends DescompIdentifier {
	@Property
	@Accessors String description
	
	@Relationship(type = "ENTITY", direction = Relationship.UNDIRECTED)
	@Accessors Set<DescompEntity> entities = new HashSet
	
	@Relationship(type = "EVENT", direction = Relationship.UNDIRECTED)
	@Accessors Set<DescompEvent> events = new HashSet;
}

@NodeEntity(label='Entity')
class DescompEntity extends DescompIdentifier {
	@Relationship(type = "HAS_ATTRIBUTE", direction = Relationship.OUTGOING)
	@Accessors Set<DescompAttribute> attributes = new HashSet
}

@NodeEntity(label='Attribute')
class DescompAttribute extends DescompIdentifier {
	@Property
	@Accessors String type
}

@NodeEntity(label='Event')
class DescompEvent extends DescompIdentifier {
	@Relationship(type = "READ_ATTRIBUTE", direction = Relationship.OUTGOING)
	@Accessors Set<DescompAttribute> readAttribute = new HashSet
}

