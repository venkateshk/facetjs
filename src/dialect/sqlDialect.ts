module Facet {
  export class SQLDialect {
    constructor() {

    }

    public offsetTimeExpression(expression: string, duration: Duration): string {
      throw new Error('Must implement offsetTimeExpression');
    }
  }

  export class MySQLDialect extends SQLDialect {
    constructor() {
      super();
    }

    public offsetTimeExpression(expression: string, duration: Duration): string {
      // https://dev.mysql.com/doc/refman/5.5/en/date-and-time-functions.html#function_date-add
      var sqlFn = "DATE_ADD("; //warpDirection > 0 ? "DATE_ADD(" : "DATE_SUB(";
      var spans = duration.valueOf();
      if (spans.week) {
        return sqlFn + expression + ", INTERVAL " + String(spans.week) + ' WEEK)';
      }
      if (spans.year || spans.month) {
        var expr = String(spans.year || 0) + "-" + String(spans.month || 0);
        expression = sqlFn + expression + ", INTERVAL '" + expr + "' YEAR_MONTH)";
      }
      if (spans.day || spans.hour || spans.minute || spans.second) {
        var expr = String(spans.day || 0) + " " + [spans.hour || 0, spans.minute || 0, spans.second || 0].join(':');
        expression = sqlFn + expression + ", INTERVAL '" + expr + "' DAY_SECOND)";
      }
      return expression
    }
  }
}
