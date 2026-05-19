const mongoose = require("mongoose");

const appointmentSchema = new mongoose.Schema(
  {
    vehicleNumber: { type: String, required: true, index: true },
    vehicleModel: { type: String },
    serviceTypes: [{ type: String }],
    branch: { type: String },
    date: { type: String },
    time: { type: String },
    Contact: { type: String },
    userId: { type: String },
    serviceCenterUid: { type: String, index: true },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected","vehicle_received"],
      default: "pending",
      index: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Appointment", appointmentSchema);
