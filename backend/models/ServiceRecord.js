const mongoose = require("mongoose");

const serviceRecordSchema = new mongoose.Schema(
  {
    userId: { type: String, index: true },
    vehicleNumber: { type: String, index: true },
    currentMileage: String,
    serviceMileage: String,
    serviceProvider: String,
    serviceCost: String,
    serviceType: String,
    oilType: String,
    notes: String,
    date: Date,
  },
  { timestamps: true, collection: "servicerecords" }
);

module.exports = mongoose.model("ServiceRecord", serviceRecordSchema);
