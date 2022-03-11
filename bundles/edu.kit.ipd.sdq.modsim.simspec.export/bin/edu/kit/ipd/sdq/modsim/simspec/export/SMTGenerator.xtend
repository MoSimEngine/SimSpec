package edu.kit.ipd.sdq.modsim.simspec.export

import edu.kit.ipd.sdq.modsim.simspec.model.behavior.Expression
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.ArrayDataType
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.BaseDataType
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.DataType
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.PrimitiveType
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.Comparator
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.Comparison
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.Constant
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.IfThenElse
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.Operator
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.Variable
import edu.kit.ipd.sdq.modsim.simspec.model.structure.Attribute
import java.util.Set
import static extension org.eclipse.emf.ecore.util.EcoreUtil.*

import static extension edu.kit.ipd.sdq.modsim.simspec.model.datatypes.TypeUtil.*
import edu.kit.ipd.sdq.modsim.simspec.model.arrayoperations.ArrayRead
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.EnumDeclaration
import edu.kit.ipd.sdq.modsim.simspec.model.datatypes.EnumType
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.BinaryOperation
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.UnaryOperator
import edu.kit.ipd.sdq.modsim.simspec.model.expressions.UnaryOperation
import edu.kit.ipd.sdq.modsim.simspec.model.arrayoperations.ArrayWrite

class SMTGenerator {
	/**
	 * Generates the complete SMT code for a delay. Delays are always of sort 'Real'.
	 * 
	 * @param delayExpr The expression that defines the value of the delay. Must be a number.
	 * @return A set of SMT commands that specify the delay.
	 */
	def String generateDelay(Expression delayExpr) {
		if (!delayExpr.type.isNumberType)
			throw new IllegalArgumentException('Delay must be a number, but has type: ' + delayExpr.type)
		
		'''
		(declare-fun delay () Real)
		«delayExpr.listReferences»
		(assert (= delay «delayExpr.generateExpressionAndCast(createDoubleType)»))
		'''
	}
	
	/**
	 * Generates the complete SMT code for a write function.
	 * 
	 * @param attribute The attribute that is overwritten by the write function. Its name and type are used to create an SMT variable. 
	 * @param writeFunction The expression that defines the value to write. Must have a type compatible with the type of attribute.
	 * @return A set of SMT commands that specify the write function.
	 */
	def String generateWritesAttribute(Attribute attribute, Iterable<Expression> writeFunctions, Iterable<Expression> conditions) {
		if (writeFunctions.length != conditions.length)
			throw new IllegalArgumentException('Different number of write functions and conditions!')
		
		var Expression x
		if ((x = writeFunctions.findFirst[!type.compatible(attribute.type)]) !== null)
			throw new IllegalArgumentException('Incompatible types: ' + x.type + ' and ' + attribute.type)
		if ((x = conditions.findFirst[!type.isBoolType]) !== null)
			throw new IllegalArgumentException('Condition must be a bool, but has type: ' + x.type)
		
		val indices = newIntArrayOfSize(writeFunctions.length)
		for (var i = 0; i < indices.length; i++) indices.set(i, i)
		
		// true if the current attribute is read in any write function or condition
		val selfRef = (writeFunctions + conditions).exists[findReferencedAttributes.contains(attribute)]
		val single = writeFunctions.length == 1
		
		'''
		«(writeFunctions + conditions).listReferences»
		(declare-fun old () «attribute.type.toSMTSort»)
		(declare-fun value () «attribute.type.toSMTSort»)
		«IF selfRef»
		(assert (= «attribute.name» old))
		«ENDIF»
		«FOR i : indices»
		(assert (=> «conditions.get(i).generateExpression» (= value «writeFunctions.get(i).generateExpressionAndCast(attribute.type)»)))
		«ENDFOR»
		«IF single»
		(assert (=> (not «conditions.head.generateExpression») (= value old)))
		«ELSE»
		(assert (=> (not (or «FOR c : conditions» «c.generateExpression» «ENDFOR»)) (= value old)))
		«ENDIF»
		'''
	}
	
	/**
	 * Generates the complete SMT code for a condition. Conditions are always of sort 'Bool'.
	 * 
	 * @param condition The expression that defines the condition.
	 * @return A set of SMT commands that specify the condition.
	 */
	def String generateCondition(Expression condition) {
		if (!condition.type.isBoolType)
			throw new IllegalArgumentException('Condition must be a bool, but has type: ' + condition.type)
		
		'''
		«condition.listReferences»
		(assert «condition.generateExpression»)
		'''
	}
	
	/**
	 * Generates SMT declarations for all attributes and enum types referenced by a given expression.
	 * 
	 * @param expr The expression for which to find references.
	 * @return A concatenation of SMT expressions that declare types and variables for the referenced enums and attributes.
	 */
	private def String listReferences(Expression expr) {
		val attributes = expr.findReferencedAttributes
		val enums = expr.findReferencedEnums
		
		'''
		«FOR e : enums»
		«e.toTypeDeclaration»
		«ENDFOR»
		«FOR attr : attributes»
		«attr.toVariableDeclaration»
		«ENDFOR»
		'''
	}
	
	/**
	 * Generates SMT declarations for all attributes and enum types referenced by a given set of expressions.
	 * 
	 * @param expr The expressions for which to find references.
	 * @return A concatenation of SMT expressions that declare types and variables for the referenced enums and attributes.
	 */
	private def String listReferences(Iterable<Expression> expr) {
		val attributes = expr.flatMap[findReferencedAttributes].toSet
		val enums = expr.flatMap[findReferencedEnums].toSet
		
		'''
		«FOR e : enums»
		«e.toTypeDeclaration»
		«ENDFOR»
		«FOR attr : attributes»
		«attr.toVariableDeclaration»
		«ENDFOR»
		'''
	}
	
	private def String generateExpressionAndCast(Expression expr, DataType targetType) {
		val generated = expr.generateExpression
		
		if (typesEqual(expr.type, targetType))
			generated
		// expression is int, needs to be double
		else if (expr.type.isIntType && targetType.isDoubleType)
			'''(to_real «generated»)'''
		// other way around
		else if (expr.type.isDoubleType && targetType.isIntType)
			'''(to_int «generated»)'''
		else
			throw new IllegalArgumentException('Type ' + expr.type + ' can\'t be cast to ' + targetType)
	}
	
	
	private def dispatch String generateExpression(BinaryOperation operation) {
		val operator = operation.operator.generateOperator(operation.left.type, operation.right.type)
		val left = operation.left.generateExpressionAndCast(operation.type)
		val right = operation.right.generateExpressionAndCast(operation.type)
		
		'''(«operator» «left» «right»)'''
	}
	
	private def dispatch String generateExpression(UnaryOperation operation) {
		val operand = operation.operand.generateExpressionAndCast(operation.type)
		
		// an SMT operator is only required for non-cast operations since the generated operand code already includes a cast
		if (operation.operator == UnaryOperator.TYPE_CAST)
			operand
		else
			'''(«operation.operator.generateUnaryOperator» «operand»)'''
	}
	
	private def dispatch String generateExpression(Comparison comparison) {
		val comparedType = combinedType(comparison.left.type, comparison.right.type)
		
		val comparator = comparison.comparator.generateComparator
		val left = comparison.left.generateExpressionAndCast(comparedType)
		val right = comparison.right.generateExpressionAndCast(comparedType)
		
		'''(«comparator» «left» «right»)'''
	}
	
	private def dispatch String generateExpression(IfThenElse ite) {
		val condition = ite.condition.generateExpression
		val thenBranch = ite.thenBranch.generateExpressionAndCast(ite.type)
		val elseBranch = ite.elseBranch.generateExpressionAndCast(ite.type)
		
		'''(ite «condition» «thenBranch» «elseBranch»)'''
	}
	
	private def dispatch String generateExpression(ArrayRead read) {
		val array = read.array.generateExpression
		val index = read.index.generateExpression
		
		'''(select «array» «index»)'''
	}
	
	private def dispatch String generateExpression(ArrayWrite write) {
		val type = (write.array.type as ArrayDataType).contentType
		val array = write.array.generateExpression
		val index = write.index.generateExpression
		val value = write.value.generateExpressionAndCast(type)
		
		'''(store «array» «index» «value»)'''
	}
	
	private def dispatch generateExpression(Constant constant) {
		constant.value
	}
	
	private def dispatch generateExpression(Variable variable) {
		variable.attribute.name
	}
	
	def generateOperator(Operator operator, DataType leftType, DataType rightType) {
		switch operator {
			case Operator.PLUS: '+'
			case Operator.MINUS: '-'
			case Operator.MULT: '*'
			// special treatment for division, '/' is only defined for Reals
			case Operator.DIV: if (leftType.isIntType && rightType.isIntType) 'div' else '/'
			case Operator.MOD: 'mod'
			case Operator.AND: 'and'
			case Operator.OR: 'or'
			default: throw new IllegalArgumentException('Unknown operator: ' + operator)
		}
	}
	
	def generateUnaryOperator(UnaryOperator operator) {
		switch (operator) {
			case UnaryOperator.MINUS: '-'
			case UnaryOperator.NEGATION: 'not'
			default: throw new IllegalArgumentException('Unknown unary operator: ' + operator)
		}
	}
	
	def generateComparator(Comparator comparator) {
		switch comparator {
			case Comparator.EQUAL: '='
			case Comparator.LESS_THAN: '<'
			case Comparator.LESS_THAN_EQUAL: '<='
			case Comparator.GREATER_THAN: '>'
			case Comparator.GREATER_THAN_EQUAL: '>='
			default: throw new IllegalArgumentException('Unknown operator: ' + comparator)
		}
	}
	
	def findReferencedAttributes(Expression expr) {
		val Set<Attribute> references = newHashSet
		val contents = expr.getAllContents(true)
		
		contents.filter(Variable).forEach[references.add(attribute)]
		if (expr instanceof Variable) references.add(expr.attribute)
		
		return references
	}
	
	def toVariableDeclaration(Attribute attribute) '''
		(declare-fun «attribute.name» () «attribute.type.toSMTSort»)
	'''
	
	def findReferencedEnums(Expression expr) {
		val Set<EnumDeclaration> references = newHashSet
		val contents = expr.getAllContents(true)
		
		contents.filter(EnumType).forEach[references.add(declaration)]
		
		return references
	}
	
	def toTypeDeclaration(EnumDeclaration declaration) '''
		(declare-datatypes ((«declaration.name» 0)) ((«FOR lit : declaration.literals» («lit») «ENDFOR»)))
	''' 
	
	/**
	 * Returns the string representation of the SMT sort to a given {@link DataType}.
	 * 
	 * @param type The data type.
	 * @return The corresponding SMT sort. 
	 */
	def String toSMTSort(DataType type) {
		switch type {
			BaseDataType : type.toPrimitiveSMTSort
			ArrayDataType : '''(Array Int «type.contentType.toSMTSort»)'''
			EnumType : type.declaration.name 
			default: throw new IllegalArgumentException('Unknown type: ' + type)
		}
	}
	
	/**
	 * Returns the string representation of the SMT sort to a given {@link BaseDataType}.
	 * 
	 * @param type The primitive type.
	 * @return The corresponding SMT sort. 
	 */
	def toPrimitiveSMTSort(BaseDataType type) {
		switch type.primitiveType {
			case PrimitiveType.INT: 'Int'
			case PrimitiveType.DOUBLE: 'Real'
			case PrimitiveType.BOOL: 'Bool'
			default: throw new IllegalArgumentException('Unknown type: ' + type.primitiveType)
		}
	}
}