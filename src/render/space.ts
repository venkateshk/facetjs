"use strict";

export class Space {
  public parent: Space;

  constructor(public parent, public node, public type, public attr) {
    this.connector = {};
    this.scale = {};
    return;
  }

  public getScale(scaleName) {
    if (this.scale.hasOwnProperty(scaleName)) {
      return this.scale[scaleName];
    } else {
      if (!this.parent) {
        throw new Error("No such scale '" + scaleName + "'");
      }
      return this.parent.getScale(scaleName);
    }
  }

  public getConnector(connectorName) {
    if (this.connector.hasOwnProperty(connectorName)) {
      return this.connector[connectorName];
    } else {
      if (!this.parent) {
        throw new Error("No such connector '" + connectorName + "'");
      }
      return this.parent.getConnector(connectorName);
    }
  }

}
