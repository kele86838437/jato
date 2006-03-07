#ifndef __STATEMENT_H
#define __STATEMENT_H

#include <list.h>
#include <expression.h>
#include <stddef.h>
#include <jam.h>

enum statement_type {
	STMT_NOP,
	STMT_STORE,
	STMT_IF,
	STMT_LABEL,
	STMT_GOTO,
	STMT_RETURN,
	STMT_EXPRESSION,
	STMT_NULL_CHECK,
	STMT_ARRAY_CHECK,
};

struct statement {
	union {
		struct tree_node node;

		/* STMT_NOP and STMT_LABEL have no fields.  */
		
		struct /* STMT_STORE */ {
			struct tree_node *store_dest;
			struct tree_node *store_src;
		};
		struct /* STMT_IF */ {
			struct tree_node *if_conditional;
			struct tree_node *if_true;
		};
		struct /* STMT_GOTO */ {
			struct tree_node *goto_target;
		};
		struct /* STMT_RETURN */ {
			struct tree_node *return_value;
		};
		/* STMT_EXPRESSION, STMT_NULL_CHECK, STMT_ARRAY_CHECK */
		struct expression *expression;
	};
	struct list_head stmt_list_node;
};

static inline struct statement *to_stmt(struct tree_node *node)
{
	return container_of(node, struct statement, node);
}

static inline enum statement_type stmt_type(struct statement *stmt)
{
	return (stmt->node.op & STMT_TYPE_MASK) >> STMT_TYPE_SHIFT;
}

struct statement *alloc_statement(enum statement_type);
void free_statement(struct statement *);

#endif
