package edu.kit.ipd.sdq.modsim.simspec.model.datatypes

import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.BaseDataType
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.DataType
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.DatatypesFactory
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.PrimitiveType
import org.eclipse.emf.ecore.util.EcoreUtil

/**
 * Contains static utility methods for Data Types.
 */
class TypeUtil {
	def static createIntType() {
		DatatypesFactory.eINSTANCE.createBaseDataType => [
			primitiveType = PrimitiveType.INT
		]
	}
	
	def static createDoubleType() {
		DatatypesFactory.eINSTANCE.createBaseDataType => [
			primitiveType = PrimitiveType.DOUBLE
		]
	}
	
	def static createBoolType() {
		DatatypesFactory.eINSTANCE.createBaseDataType => [
			primitiveType = PrimitiveType.BOOL
		]
	}
	
	def static createEnumType(EnumDeclaration dec) {
		DatatypesFactory.eINSTANCE.createEnumType => [
			declaration = dec
		]
	}
	
	def static isNumberType(DataType type) {
		type.isIntType || type.isDoubleType
	}
	
	def static isBoolType(DataType type) {
		if (type instanceof BaseDataType)
			return type.primitiveType == PrimitiveType.BOOL
		return false
	}
	
	def static isIntType(DataType type) {
		if (type instanceof BaseDataType)
			return type.primitiveType == PrimitiveType.INT
		return false
	}
	
	def static isDoubleType(DataType type) {
		if (type instanceof BaseDataType)
			return type.primitiveType == PrimitiveType.DOUBLE
		return false
	}
	
	def static isArrayType(DataType type) {
		type instanceof ArrayDataType
	}
	
	def static typesEqual(DataType type1, DataType type2) {
		val helper = new EcoreUtil.EqualityHelper()
		helper.equals(type1, type2)
	}
	
	def static compatible(DataType type1, DataType type2) {
		typesEqual(type1, type2) || (type1.isNumberType && type2.isNumberType)
	}
	
	def static combinedType(DataType type1, DataType type2) {
		if (!compatible(type1, type2))
			throw new IllegalArgumentException('Incompatible types!')
		
		// types are equal or both numbers
		if (type1.isDoubleType || type2.isDoubleType)
			return createDoubleType
		return EcoreUtil.copy(type1)
	}
	
	def static String typeName(DataType type) {
		switch (type) {
			BaseDataType: type.primitiveType.toString
			EnumType: type.declaration.name
			ArrayDataType: '''ARRAY[�type.contentType.typeName�]'''
			default: 'UNKNOWN TYPE'
		}
	}
}
